import SwiftUI
import PDFKit
import PencilKit
import Vision
import OSLog

@MainActor
@Observable
final class PdfViewerViewModel {

    // MARK: - Document state
    var document: PDFDocument?
    var pageCount: Int = 0
    var currentPage: Int = 0
    var fileName: String = ""
    var isLoading: Bool = true
    var isSaving: Bool = false
    /// Bumped whenever the document is mutated in-place (insert/delete/move pages).
    /// PDFView (UIKit, iOS 11 vintage) does NOT auto-refresh after PDFDocument
    /// mutations — same-reference reassign is a no-op. NativePdfView observes
    /// this counter and forces nil→doc reassign + scroll to currentPage.
    /// Apple bug confirmed: developer.apple.com/forums/thread/84737
    var documentRevision: Int = 0

    // MARK: - UI state
    var showThumbnails: Bool = false
    var isAnnotating: Bool = false
    var isHighlightMode: Bool = false
    var isTextMode: Bool = false
    var isLassoMode: Bool = false
    /// Modo Marcador: drag cria retângulo preto opaco (mask) pra cobrir áreas pra estudar.
    var isMaskingMode: Bool = false
    /// Study Mode: masks ficam visíveis pretas (alpha 1); tap revela conteúdo.
    var isStudyMode: Bool = false

    // MARK: - Handwriting recognition state
    var recognizedText: String? = nil
    var isRecognizing: Bool = false
    var showRecognitionResult: Bool = false
    /// Set by Coordinator so the screen can pull the current page's drawing on demand.
    var currentDrawingProvider: (() -> PKDrawing?)? = nil
    /// Set by Screen — Coordinator chama quando user toca numa mask em Study Mode.
    /// Screen apresenta StudyMaskPromptSheet.
    var onStudyMaskTap: ((StudyMaskPrompt) -> Void)? = nil
    /// Set by Screen — invocado por replaceCurrentDrawingWithFreeText pra zerar
    /// o PKCanvasView ativo da página atual (substituição Goodnotes-style).
    var onClearActiveCanvas: (() -> Void)? = nil
    /// Bounds (em coords da página) do último drawing reconhecido — usado pra
    /// posicionar a freeText annotation no MESMO local do desenho original.
    var lastRecognizedBounds: CGRect? = nil
    /// Página onde o último recognizeHandwriting foi disparado.
    var lastRecognizedPageIndex: Int? = nil

    // MARK: - Search state
    var isSearching: Bool = false
    var searchText: String = ""
    var searchResults: [PDFSelection] = []
    var currentSearchIndex: Int = 0

    private(set) var fileHash: String = ""

    // MARK: - Audio sync (Notability-style)
    /// Recorder de áudio + timeline de anotações. Bind no load(). Quando
    /// `state == .recording`, cada saveDrawing/saveHighlights registra evento
    /// com timestamp relativo ao início da gravação.
    let audioRecorder = PdfAudioRecorder()

    // MARK: - Bookmarks
    var bookmarkedPages: Set<Int> = []

    var isCurrentPageBookmarked: Bool {
        bookmarkedPages.contains(currentPage)
    }

    func toggleBookmark() {
        toggleBookmark(forPage: currentPage)
    }

    /// Toggle bookmark for any page index (used by thumbnail sidebar context menu).
    func toggleBookmark(forPage index: Int) {
        if bookmarkedPages.contains(index) {
            bookmarkedPages.remove(index)
        } else {
            bookmarkedPages.insert(index)
        }
        saveBookmarks()
    }

    /// Rotate a specific page by +90 / -90 / 180 degrees. Changes persist in
    /// the in-memory PDFDocument; saveHighlights() writes them back to disk.
    func rotatePage(at index: Int, byDegrees delta: Int) {
        guard let document, let page = document.page(at: index) else { return }
        // PDFPage.rotation is normalized to 0/90/180/270
        let newRotation = ((page.rotation + delta) % 360 + 360) % 360
        page.rotation = newRotation
        isSaving = true
        saveHighlights()
    }

    /// Move uma página no documento — suporta drag-to-reorder no thumbnail sidebar.
    /// Bookmarks são deslocados pra acompanhar a nova posição.
    func movePage(from src: Int, to dst: Int) {
        guard let document, src != dst,
              src >= 0, src < document.pageCount,
              dst >= 0, dst < document.pageCount else { return }
        document.exchangePage(at: src, withPageAt: dst)
        // Reposiciona bookmark se a página movida estava marcada.
        let srcWasBookmarked = bookmarkedPages.contains(src)
        let dstWasBookmarked = bookmarkedPages.contains(dst)
        if srcWasBookmarked != dstWasBookmarked {
            if srcWasBookmarked {
                bookmarkedPages.remove(src); bookmarkedPages.insert(dst)
            } else {
                bookmarkedPages.remove(dst); bookmarkedPages.insert(src)
            }
            saveBookmarks()
        }
        pageCount = document.pageCount
        documentRevision += 1
        isSaving = true
        saveHighlights()
    }

    /// Deleta uma página. Anotações PencilKit + bookmarks daquela página são removidos.
    func deletePage(at index: Int) {
        guard let document, index >= 0, index < document.pageCount,
              document.pageCount > 1 else { return } // não permite documento vazio
        document.removePage(at: index)
        bookmarkedPages.remove(index)
        // Reindexa bookmarks acima do índice removido.
        let above = bookmarkedPages.filter { $0 > index }
        bookmarkedPages.subtract(above)
        bookmarkedPages.formUnion(above.map { $0 - 1 })
        saveBookmarks()
        // Remove arquivo de drawing daquela página (se existir).
        let url = annotationFileURL(page: index)
        try? FileManager.default.removeItem(at: url)
        pageCount = document.pageCount
        currentPage = min(currentPage, pageCount - 1)
        documentRevision += 1
        isSaving = true
        saveHighlights()
    }

    /// Duplica uma página (insere cópia logo após o índice).
    func duplicatePage(at index: Int) {
        guard let document, let page = document.page(at: index) else { return }
        // PDFPage.copy() retorna uma cópia da página com mesmas anotações.
        guard let copy = page.copy() as? PDFPage else { return }
        document.insert(copy, at: index + 1)
        pageCount = document.pageCount
        documentRevision += 1
        isSaving = true
        saveHighlights()
    }

    /// Anexa páginas escaneadas via VisionKit no fim do documento.
    /// Cada UIImage vira uma PDFPage A4-sized.
    func appendScannedPages(_ images: [UIImage]) {
        guard let document, !images.isEmpty else { return }
        let firstNewPageIndex = document.pageCount
        for image in images {
            guard let pdfPage = PDFPage(image: image) else { continue }
            document.insert(pdfPage, at: document.pageCount)
        }
        pageCount = document.pageCount
        // Jump to first scanned page so user sees the result immediately.
        currentPage = firstNewPageIndex
        // Sinaliza pro Coordinator preservar zoom no próximo refresh — sem isso
        // o `pdfView.document = nil; doc` reseta scaleFactor pra fit-page (zoom
        // out enorme com várias páginas visíveis simultâneas, build 140 bug).
        preserveScaleOnNextRevision = true
        // Force PDFView refresh — Apple bug: same-ref reassign is no-op.
        documentRevision += 1
        isSaving = true
        saveHighlights()
    }

    /// Quando true, no próximo bump de `documentRevision` o NativePdfView
    /// faz snapshot do `scaleFactor` antes do nil→doc reassign e restaura
    /// depois. Setado por `appendScannedPages` (zoom não pode resetar).
    /// Resetado pelo Coordinator depois do refresh.
    var preserveScaleOnNextRevision: Bool = false

    /// Renderiza uma região da página atual em UIImage — usado pelo PdfScanOverlay
    /// pra mandar pra rota /api/ai/ask-image (Pergunte ao Vita com imagem).
    func captureRegionImage(rect pageRect: CGRect, pageIndex: Int) -> UIImage? {
        guard let document, let page = document.page(at: pageIndex) else { return nil }
        let pageBounds = page.bounds(for: .mediaBox)
        // Clamp pageRect dentro dos bounds reais.
        let clamped = pageRect.intersection(pageBounds)
        guard !clamped.isEmpty else { return nil }
        // Render @ 2x pra qualidade legível pelo modelo de visão.
        let scale: CGFloat = 2.0
        let outputSize = CGSize(width: clamped.width * scale, height: clamped.height * scale)
        let renderer = UIGraphicsImageRenderer(size: outputSize)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: outputSize))
            ctx.cgContext.scaleBy(x: scale, y: scale)
            ctx.cgContext.translateBy(x: -clamped.minX, y: -clamped.minY)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
    }

    func loadBookmarks() {
        let url = bookmarksFileURL()
        guard let data = try? Data(contentsOf: url),
              let pages = try? JSONDecoder().decode([Int].self, from: data) else { return }
        bookmarkedPages = Set(pages)
    }

    func saveBookmarks() {
        let url = bookmarksFileURL()
        let sorted = Array(bookmarkedPages).sorted()
        guard let data = try? JSONEncoder().encode(sorted) else { return }
        try? data.write(to: url)
    }

    private func bookmarksFileURL() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pdf_annotations", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(fileHash)_bookmarks.json")
    }

    // MARK: - Load

    private static let logger = Logger(subsystem: "com.bymav.vitaai", category: "pdf")

    func load(url: URL, tokenStore: TokenStore? = nil) async {
        fileName = url.deletingPathExtension().lastPathComponent
        fileHash = computeHash(url.absoluteString)

        let logger = Self.logger
        logger.notice("[PDF.load] url=\(url.absoluteString, privacy: .public) hasToken=\(tokenStore != nil)")
        SentryConfig.addBreadcrumb(
            message: "pdf load start",
            category: "pdf",
            data: ["url": url.absoluteString, "hasTokenStore": tokenStore != nil]
        )

        if let tokenStore, url.absoluteString.contains("/api/documents/") {
            do {
                let token = await tokenStore.token
                var request = URLRequest(url: url)
                if let token {
                    request.setValue(token, forHTTPHeaderField: "X-Extension-Token")
                }
                logger.notice("[PDF.load] fetching with auth, tokenPresent=\(token != nil)")
                let (data, response) = try await URLSession.shared.data(for: request)
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                let contentType = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type") ?? "?"
                logger.notice("[PDF.load] response status=\(status) contentType=\(contentType, privacy: .public) bytes=\(data.count)")

                if status == 200 {
                    // Validate PDF signature — backend can return 200 with HTML login page.
                    let isPDF = data.count >= 4 && data[0] == 0x25 && data[1] == 0x50 && data[2] == 0x44 && data[3] == 0x46
                    if isPDF {
                        document = PDFDocument(data: data)
                    } else {
                        let preview = String(data: data.prefix(200), encoding: .utf8) ?? "<binary>"
                        logger.error("[PDF.load] 200 but not a PDF. preview=\(preview, privacy: .public)")
                        SentryConfig.capture(message: "PDF endpoint returned 200 with non-PDF body (first bytes=\(Array(data.prefix(4))))")
                    }
                } else {
                    let body = String(data: data.prefix(500), encoding: .utf8) ?? "<binary>"
                    logger.error("[PDF.load] non-200 status=\(status) body=\(body, privacy: .public)")
                    SentryConfig.capture(message: "PDF fetch failed status=\(status) url=\(url.absoluteString)")
                }
            } catch {
                logger.error("[PDF.load] URLSession threw: \(error.localizedDescription, privacy: .public)")
                SentryConfig.capture(error: error, context: ["url": url.absoluteString, "stage": "pdf-fetch"])
            }
        } else {
            logger.notice("[PDF.load] no-auth path (PDFDocument(url:)) — \(tokenStore == nil ? "tokenStore nil" : "url not /api/documents/", privacy: .public)")
            document = PDFDocument(url: url)
            if document == nil {
                SentryConfig.capture(message: "PDFDocument(url:) returned nil (no-auth path) url=\(url.absoluteString)")
            }
        }

        pageCount = document?.pageCount ?? 0
        logger.notice("[PDF.load] done. document=\(self.document != nil) pages=\(self.pageCount)")
        loadBookmarks()
        loadHighlights()
        // Bind audio recorder ao fileHash atual — descobre se já existe áudio
        // gravado pra este PDF (state vira .loaded) ou começa do .idle.
        audioRecorder.bind(fileHash: fileHash)
        isLoading = false
    }

    // MARK: - Annotation mode

    func toggleAnnotating() {
        isAnnotating.toggle()
        if isAnnotating {
            isHighlightMode = false
            isTextMode = false
        } else {
            isLassoMode = false
        }
    }

    func toggleLassoMode() {
        guard isAnnotating else { return }
        isLassoMode.toggle()
    }

    func toggleHighlightMode() {
        isHighlightMode.toggle()
        if isHighlightMode {
            isAnnotating = false
            isTextMode = false
        }
    }

    func toggleTextMode() {
        isTextMode.toggle()
        if isTextMode {
            isAnnotating = false
            isHighlightMode = false
        }
    }

    func toggleThumbnails() { showThumbnails.toggle() }

    // MARK: - Highlight persistence (full document write, keyed by hash)

    func highlightFileURL() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pdf_annotations", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(fileHash)_highlights.pdf")
    }

    func saveHighlights() {
        guard let document else { return }
        isSaving = true
        let url = highlightFileURL()
        document.write(to: url)
        // Audio sync — registra evento de "highlight/annotation" se gravando.
        // Granularidade page-level é suficiente pro replay destacar o trecho.
        audioRecorder.recordEvent(
            type: .highlight,
            pageIndex: currentPage,
            id: "p\(currentPage)_save_\(Int(Date().timeIntervalSince1970 * 1000))"
        )
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            self.isSaving = false
        }
    }

    func loadHighlights() {
        let url = highlightFileURL()
        guard FileManager.default.fileExists(atPath: url.path),
              let saved = PDFDocument(url: url),
              let current = document else { return }
        // Copy highlight + freeText + mask annotations from saved doc into current doc
        for i in 0..<min(saved.pageCount, current.pageCount) {
            guard let savedPage = saved.page(at: i),
                  let currentPage = current.page(at: i) else { continue }
            for annotation in savedPage.annotations {
                if annotation.type == "Highlight" {
                    let copy = PDFAnnotation(bounds: annotation.bounds, forType: .highlight, withProperties: nil)
                    copy.color = annotation.color
                    currentPage.addAnnotation(copy)
                } else if PdfMaskAnnotation.isMask(annotation) {
                    // Reusar id existente pra preservar tracking de attempts
                    let id = PdfMaskAnnotation.id(for: annotation, pageIndex: i)
                    let copy = PdfMaskAnnotation.makeAnnotation(bounds: annotation.bounds, id: id)
                    currentPage.addAnnotation(copy)
                }
            }
        }
    }

    // MARK: - Search

    func toggleSearch() {
        isSearching.toggle()
        if !isSearching { clearSearch() }
    }

    func clearSearch() {
        searchText = ""
        searchResults = []
        currentSearchIndex = 0
    }

    func performSearch(_ text: String, pdfView: PDFView?) {
        guard !text.isEmpty, let document else {
            searchResults = []
            currentSearchIndex = 0
            pdfView?.highlightedSelections = nil
            pdfView?.currentSelection = nil
            return
        }
        searchResults = document.findString(text, withOptions: [.caseInsensitive, .diacriticInsensitive])
        currentSearchIndex = 0
        highlightCurrentResult(in: pdfView)
    }

    func nextResult(pdfView: PDFView?) {
        guard !searchResults.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex + 1) % searchResults.count
        highlightCurrentResult(in: pdfView)
    }

    func previousResult(pdfView: PDFView?) {
        guard !searchResults.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex - 1 + searchResults.count) % searchResults.count
        highlightCurrentResult(in: pdfView)
    }

    func highlightCurrentResult(in pdfView: PDFView?) {
        guard let pdfView else { return }
        pdfView.highlightedSelections = searchResults
        guard !searchResults.isEmpty else { return }
        let selection = searchResults[currentSearchIndex]
        pdfView.currentSelection = selection
        pdfView.go(to: selection)
        // Update current page indicator
        if let page = selection.pages.first, let doc = pdfView.document {
            let pageIndex = doc.index(for: page)
            currentPage = pageIndex
        }
    }

    func clearSearchHighlights(in pdfView: PDFView?) {
        pdfView?.highlightedSelections = nil
        pdfView?.currentSelection = nil
    }

    // MARK: - Annotation persistence (file-based, keyed by hash + page)

    func loadDrawing(pageIndex: Int) -> PKDrawing? {
        let url = annotationFileURL(page: pageIndex)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? PKDrawing(data: data)
    }

    func saveDrawing(_ drawing: PKDrawing, pageIndex: Int) {
        isSaving = true
        let url = annotationFileURL(page: pageIndex)
        try? drawing.dataRepresentation().write(to: url)
        // Audio sync — registra stroke event se gravando. Granularidade =
        // página + número de strokes (proxy razoável p/ "qual traço").
        audioRecorder.recordEvent(
            type: .stroke,
            pageIndex: pageIndex,
            id: "p\(pageIndex)_strokes_\(drawing.strokes.count)"
        )
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            self.isSaving = false
        }
    }

    func saveAllAnnotations() {
        // Coordinator calls saveDrawing per page as they scroll off-screen.
        // Nothing extra needed here — file writes are synchronous in coordinator.
    }

    /// Apaga TODAS as anotações deste PDF (drawings + highlights + bookmarks)
    /// para o `fileHash` atual. Chamado pelo PdfSettingsSheet > Limpar
    /// anotações. Irreversível.
    func resetAllAnnotations() {
        let fm = FileManager.default
        let dir = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pdf_annotations", isDirectory: true)
        guard let entries = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for url in entries where url.lastPathComponent.hasPrefix(fileHash) {
            try? fm.removeItem(at: url)
        }
        bookmarkedPages.removeAll()
        // Drop in-memory highlight annotations to mirror disk wipe.
        if let document {
            for i in 0..<document.pageCount {
                guard let page = document.page(at: i) else { continue }
                for annotation in page.annotations where annotation.type == "Highlight" {
                    page.removeAnnotation(annotation)
                }
            }
        }
    }

    // MARK: - Handwriting recognition

    func recognizeHandwriting(drawing: PKDrawing) async {
        guard !drawing.strokes.isEmpty else { return }
        isRecognizing = true

        let bounds = drawing.bounds
        // Guarda bounds + página pra eventual substituição via replaceCurrentDrawingWithFreeText.
        lastRecognizedBounds = bounds
        lastRecognizedPageIndex = currentPage
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(bounds)
            drawing.image(from: bounds, scale: 2.0).draw(in: bounds)
        }

        guard let cgImage = image.cgImage else {
            isRecognizing = false
            return
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["pt-BR", "en-US"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try await Task.detached(priority: .userInitiated) {
                try handler.perform([request])
            }.value

            let observations = request.results ?? []
            let text = observations.compactMap { obs in
                obs.topCandidates(1).first?.string
            }.joined(separator: "\n")

            recognizedText = text.isEmpty ? nil : text
            showRecognitionResult = !text.isEmpty
        } catch {
            recognizedText = nil
        }

        isRecognizing = false
    }

    /// Auto-converte handwriting → freeText sem abrir sheet.
    /// Disparado pelo Coordinator quando user pausa de escrever E o toggle
    /// `pdf.handwriting.autoConvert` está ON. Igual ao "Scribble" do Apple Notes:
    /// escreveu, virou digitado.
    ///
    /// Algoritmo:
    ///   1. Renderiza só os strokes NOVOS (delta pré-existente vs estado atual).
    ///   2. Roda VNRecognizeTextRequest.
    ///   3. Filtra: confidence >= 0.5 E texto >= 2 chars E NÃO é só símbolos.
    ///      (Threshold conservador pra não converter rabisco/seta/sublinhado.)
    ///   4. Cria PDFAnnotation .freeText no bbox dos strokes novos.
    ///   5. Remove os strokes novos do canvas (preserva strokes pré-existentes).
    ///   6. Persiste.
    ///
    /// Retorna `true` se converteu, `false` se descartou (rabisco / baixa confiança).
    func autoConvertHandwriting(
        newStrokes: [PKStroke],
        priorStrokes: [PKStroke],
        pageIndex: Int,
        applyToCanvas: (PKDrawing) -> Void
    ) async -> Bool {
        guard !newStrokes.isEmpty else { return false }
        guard let document, let page = document.page(at: pageIndex) else { return false }

        let deltaDrawing = PKDrawing(strokes: newStrokes)
        let bounds = deltaDrawing.bounds
        guard bounds.width > 4, bounds.height > 4 else { return false }

        // 2026-04-29: trocou Apple VNRecognizeTextRequest (que era pra texto
        // IMPRESSO em imagens, falhava com handwriting cru) por Google ML Kit
        // Digital Ink Recognition (modelo `pt-BR` específico pra handwriting
        // digital). Recebe os strokes diretamente — sem render pra imagem.
        // Modelo on-device, ~5MB, free.
        let result = await MLKitDigitalInkBridge.recognize(
            strokes: newStrokes,
            model: .textPtBR,
            minScore: 0.5
        )
        guard let result, !result.text.isEmpty else { return false }

        let trimmed = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2,
              trimmed.rangeOfCharacter(from: .letters) != nil else {
            return false
        }

        // 1. Cria freeText annotation no bbox dos strokes novos.
        let inset: CGFloat = 4
        let textBoundsView = bounds.insetBy(dx: inset, dy: inset)
        // PKCanvasView (overlay PDFKit) usa Y top-left; PDFAnnotation usa Y
        // bottom-left no PDF page space. Sem flip, annotation vai pra fora da
        // viewport e strokes apagam silenciosamente. Pesquisa: Apple forum
        // "PDFPageOverlayViewProvider PencilKit" + Medium "Drawing on PDF iOS".
        let pageH = page.bounds(for: .mediaBox).height
        let textBounds = CGRect(
            x: textBoundsView.minX,
            y: pageH - textBoundsView.maxY,
            width: textBoundsView.width,
            height: textBoundsView.height
        )
        let lineCount = max(1, trimmed.components(separatedBy: "\n").count)
        let fontSize = max(10, min(24, (textBounds.height / CGFloat(lineCount)) * 0.7))

        let annotation = PDFAnnotation(bounds: textBounds, forType: .freeText, withProperties: nil)
        annotation.font = UIFont.systemFont(ofSize: fontSize, weight: .regular)
        annotation.fontColor = UIColor.label
        annotation.color = .clear
        let nb = PDFBorder()
        nb.lineWidth = 0
        annotation.border = nb
        annotation.isReadOnly = false
        annotation.contents = trimmed
        page.addAnnotation(annotation)

        // 2. Remove strokes novos do canvas, preservando os pré-existentes.
        let preservedDrawing = PKDrawing(strokes: priorStrokes)
        applyToCanvas(preservedDrawing)
        saveDrawing(preservedDrawing, pageIndex: pageIndex)

        // 3. Persiste o PDF (annotations).
        saveHighlights()

        return true
    }

    /// Substitui o PKDrawing reconhecido por uma PDFAnnotation .freeText posicionada
    /// no MESMO bbox do desenho original (Goodnotes 6 "Live Text Conversion" pattern).
    /// Pré-requisito: chamar recognizeHandwriting antes — `recognizedText`,
    /// `lastRecognizedBounds` e `lastRecognizedPageIndex` precisam estar setados.
    /// Operação:
    ///   1. Cria PDFAnnotation .freeText em lastRecognizedBounds da página.
    ///   2. Limpa o PKDrawing daquela página no disco (saveDrawing PKDrawing()).
    ///   3. Zera o PKCanvasView ativo via callback onClearActiveCanvas.
    ///   4. Persiste o PDF (saveHighlights).
    func replaceCurrentDrawingWithFreeText() {
        guard let text = recognizedText,
              !text.isEmpty,
              let bounds = lastRecognizedBounds,
              let pageIndex = lastRecognizedPageIndex,
              let document,
              let page = document.page(at: pageIndex) else {
            return
        }

        // Padding leve dentro do bbox pra texto não colar nas bordas.
        let inset: CGFloat = 4
        let textBoundsView = bounds.insetBy(dx: inset, dy: inset)
        // Y-flip canvas overlay → PDF page space (idem auto-convert).
        let pageH = page.bounds(for: .mediaBox).height
        let textBounds = CGRect(
            x: textBoundsView.minX,
            y: pageH - textBoundsView.maxY,
            width: textBoundsView.width,
            height: textBoundsView.height
        )

        // Tamanho de fonte derivado da altura do desenho (mín 10pt, máx 24pt).
        // 1 linha de texto ocupa ~70% da altura do bbox; multi-linha o user
        // pode ajustar via PDFKit edit handle.
        let lineCount = max(1, text.components(separatedBy: "\n").count)
        let fontSize = max(10, min(24, (textBounds.height / CGFloat(lineCount)) * 0.7))

        let annotation = PDFAnnotation(bounds: textBounds, forType: .freeText, withProperties: nil)
        annotation.font = UIFont.systemFont(ofSize: fontSize, weight: .regular)
        annotation.fontColor = UIColor.label
        annotation.color = .clear
        let nb = PDFBorder()
        nb.lineWidth = 0
        annotation.border = nb
        annotation.isReadOnly = false
        annotation.contents = text
        page.addAnnotation(annotation)

        // Limpa o drawing do disco pra aquela página.
        saveDrawing(PKDrawing(), pageIndex: pageIndex)

        // Zera o PKCanvasView ativo (se for a página visível).
        if pageIndex == currentPage {
            onClearActiveCanvas?()
        }

        // Persiste tudo.
        saveHighlights()

        // Limpa estado da sheet.
        showRecognitionResult = false
        recognizedText = nil
        lastRecognizedBounds = nil
        lastRecognizedPageIndex = nil
    }

    // MARK: - Private helpers

    func annotationFileURL(page: Int) -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pdf_annotations", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(fileHash)_p\(page).pkdrawing")
    }

    private func computeHash(_ input: String) -> String {
        var hash: UInt64 = 5381
        for scalar in input.unicodeScalars {
            hash = (hash &<< 5) &+ hash &+ UInt64(scalar.value)
        }
        return String(hash, radix: 16)
    }
}
