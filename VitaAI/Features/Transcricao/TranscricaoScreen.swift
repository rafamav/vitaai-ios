import SwiftUI
import UIKit
import Sentry

private func openAppSettings() {
    if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
    }
}

private struct PermissionBanner: View {
    let message: String
    let onOpenSettings: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(VitaColors.accent)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .multilineTextAlignment(.leading)

                HStack(spacing: 10) {
                    Button(action: onOpenSettings) {
                        Text("Abrir Ajustes")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VitaColors.accentLight)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(VitaColors.accent.opacity(0.12))
                                    .overlay(Capsule().stroke(VitaColors.accent.opacity(0.25), lineWidth: 0.5))
                            )
                    }
                    .buttonStyle(.plain)

                    Button("Dispensar", action: onDismiss)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.45))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 12).fill(VitaColors.accent.opacity(0.06))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(VitaColors.accent.opacity(0.22), lineWidth: 0.5)
        )
    }
}

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
        .task {
            // 2026-04-23: trocado .onAppear por .task — SwiftUI re-dispara
            // .onAppear em múltiplos eventos (sheet dismiss, layout recalc,
            // tab switch), causando 6 chamadas a loadRecordings() por
            // abertura. `.task` dispara 1× por vida da view e cancela no
            // dismiss. Debounce de 2s no ViewModel cobre navigation retornada.
            if viewModel == nil {
                viewModel = TranscricaoViewModel(client: container.transcricaoClient, api: container.api, gamificationEvents: container.gamificationEvents)
            }
            await viewModel?.loadRecordings()
            SentrySDK.reportFullyDisplayed()
        }
        .onDisappear {
            // If the user is still recording, stop capture so the mic is
            // released; but NEVER reset the processing pipeline — upload /
            // transcribe / summary runs server-side and the list refresh on
            // re-enter will show the result. Calling reset() here was the
            // root cause of "ficou transcrevendo pra sempre".
            if viewModel?.phase == .recording {
                viewModel?.stopRecording()
            }
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

    /// Disciplines do semestre ATUAL apenas. `completed` (semestres passados)
    /// ficavam acumuladas e poluíam o filtro.
    private var disciplines: [String] {
        (appData.gradesResponse?.current ?? [])
            .map(\.subjectName)
            .filter { !$0.isEmpty }
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

                default:
                    // idle, recording, paused — tudo mostra a mesma lista. O
                    // pipeline cloud roda 100% em background, sem toast no
                    // topo. Cards da lista (locais) carregam o spinner de
                    // "transcrevendo" via `cloudStatus`.
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Banner de permissão negada — sutil, com CTA de
                            // "Abrir Ajustes". Só aparece quando user negou
                            // mic/speech na primeira vez. Some ao conceder.
                            if let banner = viewModel.permissionBanner {
                                PermissionBanner(
                                    message: banner,
                                    onOpenSettings: openAppSettings,
                                    onDismiss: { viewModel.permissionBanner = nil }
                                )
                                .padding(.horizontal, 16)
                                .padding(.top, 10)
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }

                            // Recorder card (mode toggle + recorder area)
                            VStack(spacing: 12) {
                                TranscricaoModeToggle(selected: $selectedMode)
                                    .disabled(viewModel.phase == .recording)

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
                                    transcribeWithAI: Binding(
                                        get: { viewModel.transcribeWithAI },
                                        set: { viewModel.transcribeWithAI = $0 }
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
                            }
                            .padding(16)
                            .glassCard(cornerRadius: 20)
                            .padding(.horizontal, 16)
                            .padding(.top, 10)

                            // (Chip Cloud/Só local foi pra dentro do recorder card
                            //  como 3º botão abaixo do idioma — Rafael pediu a
                            //  reorganização em 2026-04-24.)

                            // Live transcript — SEMPRE aparece em modo "Ao Vivo"
                            // enquanto gravando (mesmo vazio, com placeholder
                            // "Ouvindo…"). Antes só aparecia quando já tinha
                            // texto — user ficava sem feedback visual achando
                            // que o modo live não funcionava. Usa on-device
                            // SFSpeechRecognizer, zero rede.
                            if viewModel.phase == .recording && selectedMode == .live {
                                TranscricaoLiveTranscriptBox(text: viewModel.liveTranscript)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 8)
                                    .transition(.opacity)
                            }

                            // Rascunhos locais + uploads em background — cada
                            // card mostra cloudStatus ("Enviando", "Transcrevendo",
                            // "Resumindo…") via spinner/badge. Quando ready,
                            // entry migra pra lista cloud automaticamente.
                            if !viewModel.localRecordings.isEmpty {
                                TranscricaoLocalDraftsSection(
                                    drafts: viewModel.localRecordings,
                                    onTranscribe: { draft in
                                        Task { await viewModel.promoteLocalToCloud(id: draft.id) }
                                    },
                                    onDelete: { draft in
                                        withAnimation { viewModel.deleteLocalRecording(id: draft.id) }
                                    }
                                )
                                .padding(.top, 10)
                            }

                            // Recordings list (cloud)
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
                    .refreshable { await viewModel.loadRecordings(force: true) }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Detail sheet when tapping a recording.
        // presentationDetents fixado em .large: precisa mostrar TODAS as ações
        // (gerar resumo/flashcards/questões/conceitos/mindmap) sem scroll
        // escondendo opções. drag indicator visível pra user saber que é sheet.
        .sheet(item: $selectedRecording) { rec in
            TranscricaoDetailSheet(
                recording: rec,
                onRenamed: { newTitle in
                    Task { await viewModel.loadRecordings(force: true) }
                    _ = newTitle
                },
                onDeleted: {
                    withAnimation { viewModel.removeRecordingLocally(id: rec.id) }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        // Auto-abre sheet quando transcrição acabou de processar (ready).
        // UX pattern Otter/Airgram: "sua gravação tá pronta — toca o que quer
        // fazer". Evita o user ter que caçar a gravação na lista pra abrir.
        .onChange(of: viewModel.justCompletedRecordingId) { _, newId in
            guard let newId else { return }
            if let rec = viewModel.recordings.first(where: { $0.id == newId }) {
                selectedRecording = rec
                viewModel.justCompletedRecordingId = nil
            }
        }
        // Disciplines loaded from appData.gradesResponse (no separate API call needed)
    }
}
