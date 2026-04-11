import Foundation
import SwiftData
import SwiftUI

// MARK: - AssignmentTemplate
// Mirrors AssignmentTemplate.kt (Android).

struct AssignmentTemplate: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String       // SF Symbol name
    let initialContent: String
}

let assignmentTemplates: [AssignmentTemplate] = [
    AssignmentTemplate(
        id: "blank",
        name: "Em Branco",
        description: "Comece do zero",
        icon: "doc.text",
        initialContent: ""
    ),
    AssignmentTemplate(
        id: "essay",
        name: "Redação",
        description: "Introdução, desenvolvimento e conclusão",
        icon: "pencil.and.scribble",
        initialContent: "# Título\n\n## Introdução\n\n\n\n## Desenvolvimento\n\n\n\n## Conclusão\n\n"
    ),
    AssignmentTemplate(
        id: "report",
        name: "Relatório",
        description: "Relatório acadêmico estruturado",
        icon: "doc.text.magnifyingglass",
        initialContent: "# Relatório\n\n## Objetivo\n\n\n\n## Metodologia\n\n\n\n## Resultados\n\n\n\n## Discussão\n\n\n\n## Conclusão\n\n\n\n## Referências\n\n"
    ),
    AssignmentTemplate(
        id: "research",
        name: "Pesquisa",
        description: "Artigo de pesquisa acadêmica",
        icon: "flask",
        initialContent: "# Título da Pesquisa\n\n## Resumo\n\n\n\n## Introdução\n\n\n\n## Revisão de Literatura\n\n\n\n## Metodologia\n\n\n\n## Resultados\n\n\n\n## Discussão\n\n\n\n## Conclusão\n\n\n\n## Referências\n\n"
    ),
    AssignmentTemplate(
        id: "presentation",
        name: "Apresentação",
        description: "Roteiro para apresentação oral",
        icon: "play.rectangle",
        initialContent: "# Apresentação\n\n## Slide 1: Título\n\n\n\n## Slide 2: Introdução\n\n\n\n## Slide 3: Desenvolvimento\n\n\n\n## Slide 4: Conclusão\n\n\n\n## Slide 5: Perguntas\n\n"
    ),
]

// MARK: - TrabalhoEditorViewModel
// Mirrors AssignmentEditorViewModel.kt (Android ViewModel).
// Uses SwiftData ModelContext for persistence + 3s auto-save debounce.

@MainActor
@Observable
@available(iOS 17, *)
final class TrabalhoEditorViewModel {

    // MARK: State
    private(set) var id: String = ""
    var title: String = "" {
        didSet { scheduleAutoSave() }
    }
    var content: String = "" {
        didSet {
            wordCount = Self.countWords(content)
            scheduleAutoSave()
        }
    }
    private(set) var templateType: String = "blank"
    private(set) var wordCount: Int = 0
    private(set) var isLoading: Bool = true
    private(set) var isSaving: Bool = false
    private(set) var lastSavedAt: Date? = nil

    // Sheets
    private(set) var showTemplateChooser: Bool = false
    private(set) var showAiPanel: Bool = false
    private(set) var aiSuggestion: String = ""
    private(set) var isAiLoading: Bool = false

    // Submit
    private(set) var isSubmitting: Bool = false
    private(set) var submitSuccess: Bool = false
    private(set) var submitError: String? = nil
    var canSubmit: Bool { !content.isEmpty && !isSubmitting && !submitSuccess }

    // MARK: Private
    private let context: ModelContext
    private let api: VitaAPI?
    private var autoSaveTask: Task<Void, Never>? = nil

    init(context: ModelContext, api: VitaAPI? = nil) {
        self.context = context
        self.api = api
    }

    // MARK: - Load / Create

    func loadOrCreate(assignmentId: String?, templateId: String?) async {
        isLoading = true
        defer { isLoading = false }

        if let assignmentId {
            let descriptor = FetchDescriptor<LocalAssignmentEntity>(
                predicate: #Predicate { $0.id == assignmentId }
            )
            if let entity = try? context.fetch(descriptor).first {
                id = entity.id
                title = entity.title
                content = entity.content
                templateType = entity.templateType
                wordCount = Self.countWords(entity.content)
                return
            }
        }

        // Create new
        let newId = assignmentId ?? UUID().uuidString
        guard let template = assignmentTemplates.first(where: { $0.id == templateId })
            ?? assignmentTemplates.first else {
            return
        }

        id = newId
        title = ""
        content = template.initialContent
        templateType = template.id
        wordCount = Self.countWords(template.initialContent)
        showTemplateChooser = (templateId == nil)
    }

    // MARK: - Template

    func selectTemplate(_ template: AssignmentTemplate) {
        content = template.initialContent
        templateType = template.id
        wordCount = Self.countWords(template.initialContent)
        showTemplateChooser = false
        scheduleAutoSave()
    }

    func dismissTemplateChooser() {
        showTemplateChooser = false
    }

    func openTemplateChooser() {
        showTemplateChooser = true
    }

    // MARK: - AI

    func toggleAiPanel() {
        showAiPanel.toggle()
    }

    func dismissAiPanel() {
        showAiPanel = false
    }

    func requestAiSuggestion(prompt: String) {
        guard !isAiLoading, let api else { return }
        aiSuggestion = ""
        isAiLoading = true
        let assignmentId = id
        let existing = content.isEmpty ? nil : content
        Task {
            do {
                let resp = try await api.generateTrabalho(
                    id: assignmentId,
                    prompt: prompt.isEmpty ? nil : prompt,
                    existingContent: existing
                )
                aiSuggestion = resp.content
            } catch {
                NSLog("[TrabalhoEditor] AI generate error: %@", "\(error)")
                aiSuggestion = "Erro ao gerar: \(error.localizedDescription)"
            }
            isAiLoading = false
        }
    }

    /// Auto-generate full assignment text (no user prompt)
    func autoGenerate() {
        guard !isAiLoading, let api else { return }
        aiSuggestion = ""
        isAiLoading = true
        showAiPanel = true
        let assignmentId = id
        Task {
            do {
                let resp = try await api.generateTrabalho(
                    id: assignmentId,
                    prompt: nil,
                    existingContent: nil
                )
                aiSuggestion = resp.content
            } catch {
                NSLog("[TrabalhoEditor] AI auto-generate error: %@", "\(error)")
                aiSuggestion = "Erro ao gerar: \(error.localizedDescription)"
            }
            isAiLoading = false
        }
    }

    func applyAiSuggestion() {
        guard !aiSuggestion.isEmpty else { return }
        if content.isEmpty {
            content = aiSuggestion
        } else {
            content = content + "\n\n" + aiSuggestion
        }
        aiSuggestion = ""
        showAiPanel = false
        scheduleAutoSave()
    }

    // MARK: - Submit to Canvas

    func submitToCanvas() {
        guard canSubmit, let api else { return }
        isSubmitting = true
        submitError = nil
        let assignmentId = id
        let body = content
        Task {
            do {
                let resp = try await api.submitTrabalho(id: assignmentId, content: body)
                if resp.success {
                    submitSuccess = true
                    NSLog("[TrabalhoEditor] Submitted to Canvas: %@", resp.submittedAt ?? "ok")
                } else {
                    submitError = "Falha ao enviar"
                }
            } catch {
                NSLog("[TrabalhoEditor] Submit error: %@", "\(error)")
                submitError = error.localizedDescription
            }
            isSubmitting = false
        }
    }

    // MARK: - Save / Delete

    func forceSave() {
        autoSaveTask?.cancel()
        save()
    }

    func deleteAssignment() {
        let currentId = id
        let descriptor = FetchDescriptor<LocalAssignmentEntity>(
            predicate: #Predicate { $0.id == currentId }
        )
        if let entity = try? context.fetch(descriptor).first {
            context.delete(entity)
            try? context.save()
        }
    }

    // MARK: - Template label

    var templateLabel: String {
        switch templateType {
        case "essay":        return "Redação"
        case "report":       return "Relatório"
        case "research":     return "Pesquisa"
        case "presentation": return "Apresentação"
        default:             return "Livre"
        }
    }

    // MARK: - Private

    private func scheduleAutoSave() {
        autoSaveTask?.cancel()
        autoSaveTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            save()
        }
    }

    private func save() {
        let currentId = id
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let savedTitle = title.isEmpty ? "Sem título" : title
        let savedStatus = content.isEmpty ? "draft" : "in_progress"

        isSaving = true

        let descriptor = FetchDescriptor<LocalAssignmentEntity>(
            predicate: #Predicate { $0.id == currentId }
        )

        if let existing = try? context.fetch(descriptor).first {
            existing.title = savedTitle
            existing.content = content
            existing.templateType = templateType
            existing.status = savedStatus
            existing.wordCount = wordCount
            existing.updatedAt = now
        } else {
            let entity = LocalAssignmentEntity(
                id: currentId,
                title: savedTitle,
                content: content,
                templateType: templateType,
                status: savedStatus,
                wordCount: wordCount,
                createdAt: now,
                updatedAt: now
            )
            context.insert(entity)
        }

        do {
            try context.save()
            lastSavedAt = Date()
        } catch {
            print("[TrabalhoEditorVM] Save failed: \(error)")
        }

        isSaving = false
    }

    private static func countWords(_ text: String) -> Int {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return 0 }
        return text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }
}
