import SwiftUI

/// Entry point for Transcrição feature. Owns the ViewModel, routes between phases.
///
/// Sub-screens live in separate files:
///   - TranscricaoShared.swift          (TealColors, TealBackground, StatusBadge, ModeToggle, ProcessingToast, ErrorPhase)
///   - TranscricaoRecorderContent.swift (RecorderArea, DisciplineChips, LiveTranscriptBox, RecordingsList, RecordingCard)
///   - TranscricaoDetailSheet.swift     (DetailSheet, AudioPlayer, PendingContent, TranscribedContent, ActionsMenu, DonePhase, Tabs)
struct TranscricaoScreen: View {
    @Environment(\.appContainer) private var container
    let onBack: () -> Void

    @State private var viewModel: TranscricaoViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                TranscricaoContent(viewModel: vm, onBack: onBack, api: container.api)
            } else {
                ProgressView().tint(TealColors.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.clear.ignoresSafeArea())
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = TranscricaoViewModel(client: container.transcricaoClient, api: container.api, gamificationEvents: container.gamificationEvents)
                Task { await viewModel?.loadRecordings() }
            }
        }
        .onDisappear {
            viewModel?.reset()
        }
    }
}

// MARK: - Content

@MainActor
private struct TranscricaoContent: View {
    @Bindable var viewModel: TranscricaoViewModel
    let onBack: () -> Void
    let api: VitaAPI

    @State private var selectedMode: TranscricaoRecordingMode = .offline
    @State private var selectedDiscipline: String = "Geral"
    @State private var selectedFilter: String = "Todas"
    @State private var selectedRecording: TranscricaoEntry? = nil
    @State private var disciplines: [String] = ["Geral"]

    /// Whether the pipeline is actively processing (upload/transcribe/summarize/flashcards)
    private var isProcessing: Bool {
        switch viewModel.phase {
        case .uploading, .transcribing, .summarizing, .generatingFlashcards:
            return true
        default:
            return false
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                switch viewModel.phase {
                case .error:
                    TranscricaoErrorPhase(
                        message: viewModel.errorMessage ?? "Erro desconhecido",
                        onRetry: { viewModel.reset() }
                    )

                case .done:
                    TranscricaoDonePhase(
                        transcript: viewModel.transcript,
                        summary: viewModel.summary,
                        flashcards: viewModel.flashcards,
                        onReset: { viewModel.reset() }
                    )

                default:
                    // idle, recording, and processing phases all show the main scroll
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Processing toast overlay (inline, not full-screen)
                            if isProcessing {
                                TranscricaoProcessingToast(
                                    phase: viewModel.phase,
                                    percent: viewModel.progressPercent,
                                    stage: viewModel.progressStage
                                )
                                .padding(.horizontal, 16)
                                .padding(.top, 10)
                                .padding(.bottom, 6)
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }

                            // Recorder card (mode toggle + recorder area)
                            VStack(spacing: 12) {
                                TranscricaoModeToggle(selected: $selectedMode)
                                    .disabled(viewModel.phase == .recording || isProcessing)
                                    .opacity(isProcessing ? 0.5 : 1.0)

                                TranscricaoRecorderArea(
                                    elapsedSeconds: viewModel.phase == .recording ? viewModel.elapsedSeconds : 0,
                                    isRecording: viewModel.phase == .recording,
                                    selectedDiscipline: $selectedDiscipline,
                                    disciplines: disciplines,
                                    onToggle: {
                                        if viewModel.phase == .recording {
                                            viewModel.stopRecording()
                                        } else {
                                            Task { await viewModel.startRecording() }
                                        }
                                    }
                                )
                                .disabled(isProcessing)
                                .opacity(isProcessing ? 0.6 : 1.0)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 12/255, green: 9/255, blue: 7/255, opacity: 0.85),
                                                Color(red: 14/255, green: 11/255, blue: 8/255, opacity: 0.75)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(VitaColors.accent.opacity(0.10), lineWidth: 0.5)
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, isProcessing ? 4 : 10)

                            // Live transcript (if in live mode and recording)
                            if viewModel.phase == .recording && selectedMode == .live && !viewModel.liveTranscript.isEmpty {
                                TranscricaoLiveTranscriptBox(text: viewModel.liveTranscript)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 8)
                            }

                            // Recordings list
                            TranscricaoRecordingsListSection(
                                recordings: viewModel.recordings,
                                isLoading: viewModel.recordingsLoading,
                                selectedFilter: $selectedFilter,
                                filterChips: ["Todas"] + disciplines,
                                onTap: { rec in selectedRecording = rec },
                                onDelete: { rec in
                                    withAnimation {
                                        viewModel.removeRecordingLocally(id: rec.id)
                                    }
                                }
                            )
                            .padding(.top, 10)
                        }
                        .padding(.bottom, 120)
                    }
                    .animation(.easeInOut(duration: 0.3), value: isProcessing)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Detail sheet when tapping a recording
        .sheet(item: $selectedRecording) { rec in
            TranscricaoDetailSheet(recording: rec)
        }
        .task {
            // Load user's real subjects from API
            if let resp = try? await api.getSubjects() {
                let names = resp.subjects.map(\.name).filter { !$0.isEmpty }
                if !names.isEmpty {
                    disciplines = ["Geral"] + names
                }
            }
        }
    }
}
