import Foundation
import SwiftUI

@MainActor
@Observable
final class FaculdadeViewModel {
    private let api: VitaAPI

    var selectedTab: FaculdadeTab = .cursos
    var courses: [Course] = []
    var schedule: [WebalunoScheduleBlock] = []
    var grades: [WebalunoGrade] = []
    var files: [CanvasFile] = []
    var canvasConnected: Bool = true
    var webalunoConnected: Bool = false
    var isLoading: Bool = false
    var error: String? = nil
    var downloadingFileId: String? = nil
    private var downloadedFilePaths: [String: URL] = [:]

    init(api: VitaAPI) {
        self.api = api
        loadMock()
    }

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        async let coursesTask  = api.getCourses()
        async let gradesTask   = api.getWebalunoGrades()
        async let scheduleTask = api.getWebalunoSchedule()
        async let filesTask    = api.getFiles(courseId: nil)

        do {
            let (coursesResp, gradesResp, scheduleResp, filesResp) =
                try await (coursesTask, gradesTask, scheduleTask, filesTask)

            canvasConnected = coursesResp.connected
            if !coursesResp.courses.isEmpty { courses = coursesResp.courses }
            if !gradesResp.grades.isEmpty   { grades  = gradesResp.grades }
            if !scheduleResp.schedule.isEmpty { schedule = scheduleResp.schedule }
            if !filesResp.files.isEmpty     { files   = filesResp.files }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func downloadFile(fileId: String, fileName: String) async -> URL? {
        guard downloadingFileId == nil else { return nil }
        downloadingFileId = fileId
        defer { downloadingFileId = nil }

        if let cached = downloadedFilePaths[fileId] { return cached }

        do {
            let data = try await api.downloadFileData(fileId: fileId)
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("pdfs", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let dest = dir.appendingPathComponent(fileName)
            try data.write(to: dest)
            downloadedFilePaths[fileId] = dest
            return dest
        } catch {
            return nil
        }
    }

    // MARK: - Mock seed

    private func loadMock() {
        canvasConnected = true

        courses = [
            Course(id: "c1", name: "Cardiologia Clínica",        code: "CM-101", filesCount: 12, assignmentsCount: 3),
            Course(id: "c2", name: "Pneumologia e Terapia Int.", code: "CM-102", filesCount: 8,  assignmentsCount: 2),
            Course(id: "c3", name: "Neurologia",                  code: "CM-103", filesCount: 15, assignmentsCount: 4),
            Course(id: "c4", name: "Farmacologia I",              code: "CM-104", filesCount: 10, assignmentsCount: 1),
            Course(id: "c5", name: "Semiologia Médica",           code: "CM-105", filesCount: 6,  assignmentsCount: 2),
        ]

        schedule = [
            WebalunoScheduleBlock(subjectName: "Cardiologia Clínica", dayOfWeek: 1, startTime: "08:00", endTime: "10:00", room: "Sala 201", professor: "Prof. Santos"),
            WebalunoScheduleBlock(subjectName: "Neurologia",          dayOfWeek: 2, startTime: "10:00", endTime: "12:00", room: "Lab A", professor: "Profa. Lima"),
            WebalunoScheduleBlock(subjectName: "Farmacologia I",      dayOfWeek: 3, startTime: "08:00", endTime: "09:00", room: "Sala 105", professor: nil),
            WebalunoScheduleBlock(subjectName: "Pneumologia",         dayOfWeek: 4, startTime: "14:00", endTime: "16:00", room: "Sala 302", professor: "Prof. Costa"),
            WebalunoScheduleBlock(subjectName: "Semiologia Médica",   dayOfWeek: 5, startTime: "09:00", endTime: "11:00", room: "Anfiteatro", professor: "Profa. Alves"),
        ]

        grades = [
            WebalunoGrade(id: "g1", subjectName: "Cardiologia Clínica",        grade1: 8.5, grade2: 9.0, finalGrade: 8.8, status: "Aprovado", attendance: 92),
            WebalunoGrade(id: "g2", subjectName: "Pneumologia e Terapia Int.", grade1: 7.0, grade2: 6.5, finalGrade: 6.8, status: "Aprovado", attendance: 85),
            WebalunoGrade(id: "g3", subjectName: "Neurologia",                  grade1: 5.5, grade2: 6.0, finalGrade: 5.8, status: "Recuperação", attendance: 78),
            WebalunoGrade(id: "g4", subjectName: "Farmacologia I",              grade1: 9.5, finalGrade: nil, status: "Cursando", attendance: 96),
        ]

        files = [
            CanvasFile(id: "f1", displayName: "Harrison Cap. 12.pdf",     contentType: "application/pdf", courseName: "Cardiologia Clínica",       moduleName: "Módulo 1"),
            CanvasFile(id: "f2", displayName: "Diretriz ICC 2024.pdf",     contentType: "application/pdf", courseName: "Cardiologia Clínica",       moduleName: "Módulo 1"),
            CanvasFile(id: "f3", displayName: "Pneumo Avançada.pdf",       contentType: "application/pdf", courseName: "Pneumologia e Terapia Int.", moduleName: "Módulo 2"),
            CanvasFile(id: "f4", displayName: "Guyton Fisiologia.pdf",     contentType: "application/pdf", courseName: "Neurologia",                moduleName: nil),
            CanvasFile(id: "f5", displayName: "Síndromes Neurológicas.pdf",contentType: "application/pdf", courseName: "Neurologia",                moduleName: "Módulo 3"),
        ]
    }
}
