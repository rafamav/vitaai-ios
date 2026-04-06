import Foundation

/// Orchestrates the full Canvas sync flow on-device:
/// 1. Fetch user, courses, assignments, files, calendar events from Canvas REST API
/// 2. Filter PDFs that look like planos de ensino (by name regex + size < 10MB)
/// 3. Download matching PDFs
/// 4. Build CanvasIngestPayload and POST to Vita backend for LLM processing
actor CanvasSyncOrchestrator {
    enum Phase: String {
        case starting = "Conectando ao Canvas..."
        case fetchingCourses = "Buscando disciplinas..."
        case fetchingData = "Buscando atividades e arquivos..."
        case filteringPDFs = "Identificando planos de ensino..."
        case downloadingPDFs = "Baixando planos de ensino..."
        case uploading = "Enviando para Vita processar..."
        case done = "Extração completa!"
        case error = "Erro na extração"
    }

    struct Progress {
        let phase: Phase
        let detail: String?
        let percent: Double
    }

    private let canvasClient: CanvasAPIClient
    private let vitaAPI: VitaAPI
    private let instanceUrl: String
    private let cookies: String
    private let onProgress: @Sendable (Progress) -> Void

    /// Max PDF size to download (5 MB — planos de ensino are small docs).
    private static let maxPdfSize = 5 * 1024 * 1024
    /// Max total raw bytes before base64 (30 MB cap to keep payload sane).
    private static let maxTotalPdfBytes = 30 * 1024 * 1024
    /// Max number of PDFs to download per sync.
    private static let maxPdfCount = 10

    /// Regex patterns for plano de ensino filenames (applied after accent stripping).
    /// Only matches actual planos — NOT cronogramas, horarios, calendarios, etc.
    private static let planoPatterns: [String] = [
        "plano",
        "ementa",
    ]

    init(cookies: String, instanceUrl: String, vitaAPI: VitaAPI, onProgress: @escaping @Sendable (Progress) -> Void) {
        self.canvasClient = CanvasAPIClient(instanceUrl: instanceUrl, cookies: cookies)
        self.vitaAPI = vitaAPI
        self.instanceUrl = instanceUrl
        self.cookies = cookies
        self.onProgress = onProgress
    }

    // MARK: - Run

    func run() async throws -> CanvasIngestResponse {
        // 1. Fetch user
        report(.starting, detail: nil, percent: 5)
        let user: CanvasAPIUser?
        do {
            user = try await canvasClient.fetchUser()
            NSLog("[CanvasSync] User: %@ (%d)", user?.name ?? "?", user?.id ?? 0)
        } catch {
            NSLog("[CanvasSync] Failed to fetch user (non-fatal): %@", error.localizedDescription)
            user = nil
        }

        try Task.checkCancellation()

        // 2. Fetch courses
        report(.fetchingCourses, detail: nil, percent: 10)
        let courses = try await canvasClient.fetchCourses()
        NSLog("[CanvasSync] Found %d courses", courses.count)

        try Task.checkCancellation()

        // 3. Fetch assignments + files per course
        report(.fetchingData, detail: "0/\(courses.count) disciplinas", percent: 20)
        var allAssignments: [(courseId: Int, assignment: CanvasAPIAssignment)] = []
        var allFiles: [(courseId: Int, file: CanvasAPIFile)] = []
        var fetchErrors: [[String: Any]] = []

        for (i, course) in courses.enumerated() {
            try Task.checkCancellation()
            let pct = 20.0 + (30.0 * Double(i) / max(Double(courses.count), 1))
            report(.fetchingData, detail: "\(i + 1)/\(courses.count) disciplinas", percent: pct)

            do {
                let assignments = try await canvasClient.fetchAssignments(courseId: course.id)
                for a in assignments { allAssignments.append((courseId: course.id, assignment: a)) }
            } catch {
                NSLog("[CanvasSync] Assignments error for course %d: %@", course.id, error.localizedDescription)
                fetchErrors.append(["source": "assignments", "courseId": "\(course.id)", "error": error.localizedDescription])
            }

            do {
                let files = try await canvasClient.fetchFiles(courseId: course.id)
                for f in files { allFiles.append((courseId: course.id, file: f)) }
            } catch {
                NSLog("[CanvasSync] Files error for course %d: %@", course.id, error.localizedDescription)
                fetchErrors.append(["source": "files", "courseId": "\(course.id)", "error": error.localizedDescription])
            }
        }

        NSLog("[CanvasSync] Total: %d assignments, %d files", allAssignments.count, allFiles.count)

        // 4. Fetch calendar events
        let calendarEvents: [CanvasAPICalendarEvent]
        do {
            calendarEvents = try await canvasClient.fetchCalendarEvents()
            NSLog("[CanvasSync] Calendar events: %d", calendarEvents.count)
        } catch {
            NSLog("[CanvasSync] Calendar error (non-fatal): %@", error.localizedDescription)
            calendarEvents = []
            fetchErrors.append(["source": "calendar", "error": error.localizedDescription])
        }

        try Task.checkCancellation()

        // 5. Filter PDFs via LLM (ask backend which files are planos de ensino)
        report(.filteringPDFs, detail: "Consultando IA...", percent: 55)
        let allPdfs = allFiles.filter { item in
            guard let ct = item.file.contentType, ct.contains("pdf") else { return false }
            return item.file.size > 0 && item.file.size <= Self.maxPdfSize
        }
        NSLog("[CanvasSync] Total PDFs: %d (out of %d files)", allPdfs.count, allFiles.count)

        var pdfCandidates: [(courseId: Int, file: CanvasAPIFile)] = []
        if !allPdfs.isEmpty {
            // Send file metadata to backend — LLM decides which to download
            let fileMeta: [[String: Any]] = allPdfs.map { item in
                [
                    "id": "\(item.file.id)",
                    "displayName": item.file.displayName,
                    "contentType": item.file.contentType ?? "application/pdf",
                    "size": item.file.size,
                ]
            }

            do {
                let filterResult = try await vitaAPI.filterFiles(fileMeta)
                let relevantIds = Set(filterResult.relevantFileIds)
                pdfCandidates = allPdfs.filter { relevantIds.contains("\($0.file.id)") }
                NSLog("[CanvasSync] LLM selected %d/%d PDFs (fallback: %@)",
                      pdfCandidates.count, allPdfs.count, filterResult.fallback == true ? "yes" : "no")
            } catch {
                // LLM unavailable — use regex fallback locally
                NSLog("[CanvasSync] Filter API failed, using regex fallback: %@", error.localizedDescription)
                pdfCandidates = allPdfs.filter { Self.matchesPlanoPattern($0.file.displayName) }
                NSLog("[CanvasSync] Regex fallback selected %d/%d PDFs", pdfCandidates.count, allPdfs.count)
            }
        }

        try Task.checkCancellation()

        // 6. Download only LLM-selected PDFs (capped by count + total size)
        var pdfContents: [[String: Any]] = []
        var totalPdfBytes = 0
        let cappedCandidates = Array(pdfCandidates.prefix(Self.maxPdfCount))
        if !cappedCandidates.isEmpty {
            report(.downloadingPDFs, detail: "0/\(cappedCandidates.count)", percent: 60)
            for (i, item) in cappedCandidates.enumerated() {
                try Task.checkCancellation()
                let pct = 60.0 + (20.0 * Double(i) / Double(cappedCandidates.count))
                report(.downloadingPDFs, detail: "\(i + 1)/\(cappedCandidates.count) PDFs", percent: pct)

                // Stop if we'd exceed total payload cap
                if totalPdfBytes + item.file.size > Self.maxTotalPdfBytes {
                    NSLog("[CanvasSync] Total PDF size cap reached (%d bytes), skipping remaining", totalPdfBytes)
                    break
                }

                guard let downloadUrl = item.file.url, !downloadUrl.isEmpty else {
                    NSLog("[CanvasSync] No download URL for file %d", item.file.id)
                    continue
                }

                do {
                    let data = try await canvasClient.downloadFile(url: downloadUrl)
                    totalPdfBytes += data.count
                    let base64 = data.base64EncodedString()
                    pdfContents.append([
                        "canvasFileId": "\(item.file.id)",
                        "displayName": item.file.displayName,
                        "contentType": item.file.contentType ?? "application/pdf",
                        "sizeBytes": data.count,
                        "base64": base64,
                    ])
                    NSLog("[CanvasSync] Downloaded PDF: %@ (%d bytes, total: %d)", item.file.displayName, data.count, totalPdfBytes)
                } catch {
                    NSLog("[CanvasSync] PDF download failed: %@ — %@", item.file.displayName, error.localizedDescription)
                    fetchErrors.append(["source": "pdf_download", "fileId": "\(item.file.id)", "error": error.localizedDescription])
                }
            }
        }

        try Task.checkCancellation()

        // 7. Build ingest payload
        report(.uploading, detail: nil, percent: 85)

        let payload = CanvasIngestPayload(
            instanceUrl: instanceUrl,
            user: user.map { [
                "id": $0.id,
                "name": $0.name,
                "loginId": $0.loginId as Any,
            ] },
            courses: courses.map { Self.courseToDict($0) },
            assignments: allAssignments.map { Self.assignmentToDict($0.courseId, $0.assignment) },
            files: allFiles.map { Self.fileToDict($0.courseId, $0.file) },
            calendarEvents: calendarEvents.map { Self.calendarEventToDict($0) },
            errors: fetchErrors,
            pdfContents: pdfContents,
            sessionCookies: cookies
        )

        // 8. POST to backend
        let response = try await vitaAPI.ingestCanvasData(payload)
        report(.done, detail: nil, percent: 100)
        NSLog("[CanvasSync] Ingest complete: traceId=%@ courses=%d, assignments=%d, files=%d, pdfs=%d",
              response.traceId ?? "?", response.courses ?? 0, response.assignments ?? 0, response.files ?? 0, response.pdfExtracted ?? 0)
        return response
    }

    // MARK: - PDF Name Matching

    /// Strips diacritics (accents) and checks against plano patterns.
    static func matchesPlanoPattern(_ filename: String) -> Bool {
        let normalized = filename
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
            .lowercased()
        for pattern in planoPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(normalized.startIndex..., in: normalized)
                if regex.firstMatch(in: normalized, range: range) != nil {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Progress

    private func report(_ phase: Phase, detail: String?, percent: Double) {
        let p = Progress(phase: phase, detail: detail, percent: percent)
        onProgress(p)
    }

    // MARK: - Dict Builders (camelCase keys matching openapi.yaml)

    private static func courseToDict(_ c: CanvasAPICourse) -> [String: Any] {
        var d: [String: Any] = [
            "canvasCourseId": "\(c.id)",
            "name": c.name,
            "enrollmentType": c.enrollments?.first?.type ?? "student",
            "teachers": c.teachers?.compactMap { $0.displayName } ?? [],
        ]
        if let code = c.courseCode { d["code"] = code }
        if let term = c.term?.name { d["term"] = term }
        if let e = c.enrollments?.first {
            if let s = e.computedCurrentScore { d["currentScore"] = s }
            if let s = e.computedFinalScore { d["finalScore"] = s }
            if let g = e.computedCurrentGrade { d["currentGrade"] = g }
            if let g = e.computedFinalGrade { d["finalGrade"] = g }
        }
        return d
    }

    private static func assignmentToDict(_ courseId: Int, _ a: CanvasAPIAssignment) -> [String: Any] {
        var d: [String: Any] = [
            "canvasAssignmentId": "\(a.id)",
            "canvasCourseId": "\(courseId)",
            "name": a.name,
        ]
        if let desc = a.description { d["description"] = desc }
        if let due = a.dueAt { d["dueAt"] = due }
        if let pts = a.pointsPossible { d["pointsPossible"] = pts }
        if let sub = a.submission {
            if let s = sub.score { d["score"] = s }
            if let g = sub.grade { d["grade"] = g }
            if let t = sub.submittedAt { d["submittedAt"] = t }
        }
        return d
    }

    private static func fileToDict(_ courseId: Int, _ f: CanvasAPIFile) -> [String: Any] {
        var d: [String: Any] = [
            "canvasFileId": "\(f.id)",
            "canvasCourseId": "\(courseId)",
            "displayName": f.displayName,
            "contentType": f.contentType ?? "application/octet-stream",
            "size": f.size,
        ]
        if let url = f.url { d["downloadUrl"] = url }
        return d
    }

    private static func calendarEventToDict(_ e: CanvasAPICalendarEvent) -> [String: Any] {
        var d: [String: Any] = [
            "canvasEventId": "\(e.id)",
            "title": e.title ?? "",
        ]
        if let s = e.startAt { d["startAt"] = s }
        if let s = e.endAt { d["endAt"] = s }
        if let ct = e.contextType { d["contextType"] = ct }
        return d
    }
}
