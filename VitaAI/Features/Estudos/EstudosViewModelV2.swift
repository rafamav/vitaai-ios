import Foundation
import SwiftUI

// MARK: - EstudosViewModel (V2 — 5-block architecture)
// Replaces the old tab-based ViewModel with the new spec:
// Block 1: Continuar de Onde Parou
// Block 2: Recomendado Para Ti
// Block 3: Biblioteca de Ferramentas (static)
// Block 4: Materiais Recentes
// Block 5: Sessoes Recentes

@MainActor
@Observable
final class EstudosViewModelV2 {
    private let api: VitaAPI
    private let estudosAPI: EstudosAPIService

    // MARK: - State

    enum LoadState {
        case loading
        case loaded
        case error(String)
    }

    private(set) var loadState: LoadState = .loading

    // Block 1: Continuar de Onde Parou
    private(set) var continueItems: [ContinueItem] = []

    // Block 2: Recomendado Para Ti
    private(set) var recommendation: VitaRecommendation?

    // Block 3: Biblioteca de Ferramentas (static from ToolDefinition)

    // Block 4: Materiais Recentes
    private(set) var recentMaterials: [RecentMaterial] = []

    // Block 5: Sessoes Recentes
    private(set) var recentSessions: [StudySessionEntry] = []

    // MARK: - Init

    init(api: VitaAPI, httpClient: HTTPClient) {
        self.api = api
        self.estudosAPI = EstudosAPIService(client: httpClient)
    }

    // MARK: - Load

    func load() async {
        loadState = .loading

        async let sessionsTask: StudySessionsResponse? = try? await estudosAPI.getStudySessions(limit: 10)
        async let documentsTask: DocumentsResponse? = try? await estudosAPI.getDocuments(limit: 10)
        async let outputsTask: StudioOutputsResponse? = try? await estudosAPI.getStudioOutputs(limit: 10)
        async let memoryTask: VitaMemoryResponse? = try? await estudosAPI.getVitaMemory()
        async let progressTask: ProgressResponse? = try? await api.getProgress()
        async let flashcardTask: [FlashcardDeckEntry]? = try? await api.getFlashcardDecks(dueOnly: false)
        async let transcricoesTask: [TranscricaoListEntry]? = try? await estudosAPI.getTranscricoes()
        async let notesTask: [NoteListEntry]? = try? await estudosAPI.getNotes(limit: 10)
        async let simuladoTask: SimuladoListResponse? = try? await api.listSimulados()

        let sessions = await sessionsTask
        let documents = await documentsTask
        let outputs = await outputsTask
        let memory = await memoryTask
        let progress = await progressTask
        let flashcardDecks = await flashcardTask ?? []
        let transcricoes = await transcricoesTask ?? []
        let notes = await notesTask ?? []
        let simulados = await simuladoTask

        // Block 1: Build continue items from incomplete work
        continueItems = buildContinueItems(
            documents: documents?.documents ?? [],
            simulados: simulados,
            flashcardDecks: flashcardDecks,
            transcricoes: transcricoes,
            progress: progress
        )

        // Block 2: Recommendation from Vita memory
        recommendation = memory?.recommendations.first

        // Block 4: Recent materials
        recentMaterials = buildRecentMaterials(
            documents: documents?.documents ?? [],
            outputs: outputs?.outputs ?? [],
            transcricoes: transcricoes,
            notes: notes
        )

        // Block 5: Recent sessions
        recentSessions = sessions?.sessions ?? []

        loadState = .loaded
    }

    // MARK: - Builders

    private func buildContinueItems(
        documents: [DocumentItem],
        simulados: SimuladoListResponse?,
        flashcardDecks: [FlashcardDeckEntry],
        transcricoes: [TranscricaoListEntry],
        progress: ProgressResponse?
    ) -> [ContinueItem] {
        var items: [ContinueItem] = []

        // PDFs in progress
        for doc in documents.prefix(2) {
            guard let readProgress = doc.readProgress,
                  readProgress > 0 && readProgress < 1.0 else { continue }
            items.append(ContinueItem(
                id: "pdf-\(doc.id)",
                type: .pdf,
                title: doc.title,
                subtitle: String(localized: "\(doc.progressPercent)% lido"),
                progress: readProgress,
                icon: "doc.text.fill"
            ))
        }

        // Incomplete simulados
        if let attempts = simulados?.attempts {
            for attempt in attempts.prefix(2) {
                guard attempt.status == "in_progress" else { continue }
                let answered = attempt.correctQ
                let total = attempt.totalQ
                let prog = total > 0 ? Double(answered) / Double(total) : 0.0
                items.append(ContinueItem(
                    id: "simulado-\(attempt.id)",
                    type: .simulado,
                    title: attempt.title.isEmpty
                        ? String(localized: "Simulado")
                        : attempt.title,
                    subtitle: String(localized: "\(answered)/\(total) questoes"),
                    progress: prog,
                    icon: "text.badge.checkmark"
                ))
            }
        }

        // Flashcard decks with remaining cards
        let dueDecks = flashcardDecks
            .filter { !$0.cards.isEmpty }
            .sorted { $0.cards.count > $1.cards.count }

        for deck in dueDecks.prefix(2) {
            let reviewed = deck.cards.filter { $0.repetitions > 0 }.count
            let total = deck.cards.count
            let prog = total > 0 ? Double(reviewed) / Double(total) : 0.0
            guard prog < 1.0 else { continue }
            items.append(ContinueItem(
                id: "flashcard-\(deck.id)",
                type: .flashcard,
                title: deck.title,
                subtitle: String(localized: "\(reviewed)/\(total) cards"),
                progress: prog,
                icon: "rectangle.on.rectangle.angled"
            ))
        }

        // Recent transcricoes
        for transcricao in transcricoes.prefix(1) {
            guard transcricao.status == "completed" else { continue }
            items.append(ContinueItem(
                id: "transcricao-\(transcricao.id)",
                type: .transcricao,
                title: transcricao.title,
                subtitle: String(localized: "Transcricao concluida"),
                progress: 1.0,
                icon: "waveform"
            ))
        }

        return Array(items.prefix(6))
    }

    private func buildRecentMaterials(
        documents: [DocumentItem],
        outputs: [StudioOutputItem],
        transcricoes: [TranscricaoListEntry],
        notes: [NoteListEntry]
    ) -> [RecentMaterial] {
        var materials: [RecentMaterial] = []

        for doc in documents.prefix(3) {
            materials.append(RecentMaterial(
                id: "doc-\(doc.id)",
                type: .document,
                title: doc.title,
                subtitle: doc.fileName,
                createdAt: doc.createdAt
            ))
        }

        for output in outputs.prefix(2) {
            materials.append(RecentMaterial(
                id: "output-\(output.id)",
                type: .studioOutput,
                title: output.title,
                subtitle: output.sourceName,
                createdAt: output.createdAt
            ))
        }

        for entry in transcricoes.prefix(2) {
            materials.append(RecentMaterial(
                id: "trans-\(entry.id)",
                type: .transcricao,
                title: entry.title,
                subtitle: entry.status,
                createdAt: entry.createdAt
            ))
        }

        for note in notes.prefix(2) {
            materials.append(RecentMaterial(
                id: "note-\(note.id)",
                type: .note,
                title: note.title,
                subtitle: nil,
                createdAt: note.updatedAt
            ))
        }

        return Array(materials.prefix(8))
    }
}
