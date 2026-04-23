import SwiftUI
import Sentry

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
                ProgressView().tint(VitaColors.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.clear.ignoresSafeArea())
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = TranscricaoViewModel(client: container.transcricaoClient, api: container.api, gamificationEvents: container.gamificationEvents)
                Task {
                    await viewModel?.loadRecordings()
                    SentrySDK.reportFullyDisplayed()
                }
            }
        }
        .onDisappear {
            viewModel?.reset()
        }
        .trackScreen("Transcricao")
    }
}

// MARK: - Content

@MainActor
private struct TranscricaoContent: View {
    @Bindable var viewModel: TranscricaoViewModel
    let onBack: () -> Void
    let api: VitaAPI

    @Environment(\.appData) private var appData
    @State private var selectedMode: TranscricaoRecordingMode = .offline
    // `selectedDiscipline` lives on the ViewModel so it flows into the upload
    // payload (R2 metadata + backend) without a second piece of state.
    @State private var selectedFilter: String? = nil
    @State private var selectedRecording: TranscricaoEntry? = nil

    /// Disciplines from academic_subjects via gradesResponse (already loaded by AppDataManager)
    private var disciplines: [String] {
        let current = appData.gradesResponse?.current ?? []
        let completed = appData.gradesResponse?.completed ?? []
        let all = current + completed
        return all.map(\.subjectName).filter { !$0.isEmpty }
    }

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
                                    elapsedSeconds: (viewModel.phase == .recording || viewModel.phase == .paused) ? viewModel.elapsedSeconds : 0,
                                    isRecording: viewModel.phase == .recording,
                                    isPaused: viewModel.phase == .paused,
                                    audioLevels: viewModel.audioLevels,
                                    selectedDiscipline: Binding(
                                        get: { viewModel.selectedDiscipline },
                                        set: { viewModel.selectedDiscipline = $0 }
                                    ),
                                    selectedLanguage: Binding(
                                        get: { viewModel.selectedLanguage },
                                        set: { viewModel.selectedLanguage = $0 }
                                    ),
                                    disciplines: disciplines,
                                    onToggle: {
                                        if viewModel.phase == .recording || viewModel.phase == .paused {
                                            viewModel.stopRecording()
                                        } else {
                                            Task { await viewModel.startRecording() }
                                        }
                                    },
                                    onPauseResume: {
                                        if viewModel.phase == .recording {
                                            viewModel.pauseRecording()
                                        } else if viewModel.phase == .paused {
                                            viewModel.resumeRecording()
                                        }
                                    }
                                )
                                .disabled(isProcessing)
                                .opacity(isProcessing ? 0.6 : 1.0)
                            }
                            .padding(16)
                            .glassCard(cornerRadius: 20)
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
                                filterChips: disciplines,
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
                    .refreshable { await viewModel.loadRecordings() }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Detail sheet when tapping a recording
        .sheet(item: $selectedRecording) { rec in
            TranscricaoDetailSheet(recording: rec)
        }
        // Disciplines loaded from appData.gradesResponse (no separate API call needed)
    }
}
