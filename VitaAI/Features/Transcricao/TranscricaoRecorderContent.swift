import SwiftUI

// MARK: - Recorder Area (timer + waveform + discipline chips + record button)

struct TranscricaoRecorderArea: View {
    let elapsedSeconds: Int
    let isRecording: Bool
    @Binding var selectedDiscipline: String
    let disciplines: [String]
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Left side: timer + status + waveform + discipline chips + stop btn
            VStack(alignment: .leading, spacing: 0) {
                // Timer
                Text(formatTranscricaoElapsed(elapsedSeconds))
                    .font(.system(size: 36, weight: .bold, design: .default))
                    .tracking(-1.5)
                    .monospacedDigit()
                    .foregroundStyle(
                        isRecording
                            ? TealColors.accentLight.opacity(0.95)
                            : Color.white.opacity(0.22)
                    )
                    .shadow(color: isRecording ? TealColors.accent.opacity(0.4) : .clear, radius: 24)

                // Status label
                Text(isRecording ? "Gravando..." : "Pronto para gravar")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(
                        isRecording
                            ? TealColors.accentLight.opacity(0.70)
                            : Color.white.opacity(0.25)
                    )
                    .padding(.top, 2)

                // Waveform bars
                HStack(spacing: 1.5) {
                    ForEach(0..<24, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                isRecording
                                    ? LinearGradient(
                                        colors: [TealColors.accent.opacity(0.5), TealColors.accentLight.opacity(0.85)],
                                        startPoint: .bottom,
                                        endPoint: .top
                                      )
                                    : LinearGradient(
                                        colors: [TealColors.accent.opacity(0.10)],
                                        startPoint: .bottom,
                                        endPoint: .top
                                      )
                            )
                            .frame(
                                width: 2.5,
                                height: isRecording
                                    ? CGFloat.random(in: 6...34)
                                    : 6
                            )
                    }
                }
                .frame(height: 36)
                .padding(.top, 8)
                .animation(
                    isRecording
                        ? .easeInOut(duration: 0.3).repeatForever(autoreverses: true)
                        : .default,
                    value: isRecording
                )

                // Discipline chips below waveform
                TranscricaoDisciplineChips(
                    disciplines: disciplines,
                    selected: $selectedDiscipline,
                    disabled: isRecording
                )
                .padding(.top, 4)

                // Stop button (only visible when recording)
                if isRecording {
                    Button(action: onToggle) {
                        Text("Parar gravação")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(TealColors.accentBright.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(TealColors.accent.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(TealColors.accent.opacity(0.18), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }

            // Right side: recorder image button
            Button(action: {
                if !isRecording { onToggle() }
            }) {
                VStack(spacing: 4) {
                    Image("btn-transcricao")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 155)
                        .shadow(color: TealColors.accent.opacity(0.30), radius: 20)
                        .opacity(isRecording ? 0.7 : 1.0)
                        .scaleEffect(isRecording ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 0.4), value: isRecording)

                    Text(isRecording ? "Gravando..." : "Toque para gravar")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(
                            isRecording
                                ? TealColors.accentLight.opacity(0.70)
                                : Color.white.opacity(0.22)
                        )
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 10)
    }
}

// MARK: - Discipline Chips

struct TranscricaoDisciplineChips: View {
    let disciplines: [String]
    @Binding var selected: String
    let disabled: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(disciplines, id: \.self) { disc in
                    Button {
                        if !disabled {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selected = disc
                            }
                        }
                    } label: {
                        Text(disc)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(
                                selected == disc
                                    ? TealColors.accentBright.opacity(0.85)
                                    : Color.white.opacity(0.28)
                            )
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        selected == disc
                                            ? TealColors.accent.opacity(0.08)
                                            : Color.white.opacity(0.06)
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        selected == disc
                                            ? TealColors.accent.opacity(0.28)
                                            : TealColors.accent.opacity(0.06),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .opacity(disabled ? 0.5 : 1.0)
                }
            }
        }
    }
}

// MARK: - Live Transcript Box

struct TranscricaoLiveTranscriptBox: View {
    let text: String

    var body: some View {
        ScrollView(showsIndicators: false) {
            Text(text)
                .font(.system(size: 12))
                .lineSpacing(4)
                .foregroundStyle(Color.white.opacity(0.65))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
        }
        .frame(maxHeight: 120)
        .background(TealColors.accent.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(TealColors.accent.opacity(0.10), lineWidth: 1)
        )
    }
}

// MARK: - Recordings List Section (data from API)

struct TranscricaoRecordingsListSection: View {
    let recordings: [TranscricaoEntry]
    let isLoading: Bool
    @Binding var selectedFilter: String
    let filterChips: [String]
    let onTap: (TranscricaoEntry) -> Void
    let onDelete: (TranscricaoEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Filter chips (horizontal scroll)
            TranscricaoFilterChips(chips: filterChips, selected: $selectedFilter)
                .padding(.horizontal, 16)

            // Section label
            Text("GRAVAÇÕES")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(VitaColors.textWarm.opacity(0.55))
                .tracking(0.5)
                .padding(.horizontal, 16)
                .padding(.top, 2)
                .padding(.bottom, 4)

            if isLoading {
                ProgressView()
                    .tint(TealColors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else if recordings.isEmpty {
                // Empty state
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [VitaColors.accent.opacity(0.12), VitaColors.accent.opacity(0.03)],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 40
                                )
                            )
                            .frame(width: 80, height: 80)
                        Image(systemName: "waveform.and.mic")
                            .font(.system(size: 30, weight: .light))
                            .foregroundStyle(VitaColors.accent.opacity(0.55))
                    }

                    Text("Nenhuma gravação ainda")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.65))

                    Text("Grave sua primeira aula para transcrever.\nA IA gera resumos e flashcards automaticamente.")
                        .font(.system(size: 12))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.35))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .padding(.horizontal, 32)
            } else {
                List {
                    ForEach(recordings) { rec in
                        TealGlassRecordingCard(recording: rec)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .contentShape(Rectangle())
                            .onTapGesture { onTap(rec) }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    onDelete(rec)
                                } label: {
                                    Label("Excluir", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(minHeight: CGFloat(recordings.count) * 80)
            }
        }
    }
}

// MARK: - Filter Chips

struct TranscricaoFilterChips: View {
    let chips: [String]
    @Binding var selected: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(chips, id: \.self) { chip in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selected = chip
                        }
                    } label: {
                        Text(chip)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(
                                selected == chip
                                    ? TealColors.accentBright.opacity(0.85)
                                    : Color.white.opacity(0.28)
                            )
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        selected == chip
                                            ? TealColors.accent.opacity(0.08)
                                            : Color.white.opacity(0.06)
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        selected == chip
                                            ? TealColors.accent.opacity(0.28)
                                            : TealColors.accent.opacity(0.06),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Teal Glass Recording Card

struct TealGlassRecordingCard: View {
    let recording: TranscricaoEntry

    private var displayStatus: RecordingStatus {
        recording.isTranscribed ? .transcribed : .pending
    }

    var body: some View {
        HStack(spacing: 14) {
            // Mic icon in teal glass circle
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                TealColors.accent.opacity(displayStatus == .pending ? 0.15 : 0.32),
                                TealColors.accent.opacity(displayStatus == .pending ? 0.06 : 0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(TealColors.accent.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.40), radius: 6, y: 3)

                Image(systemName: "mic.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(VitaColors.accentLight.opacity(0.92))
            }
            .opacity(displayStatus == .pending ? 0.5 : 1.0)

            // Text block
            VStack(alignment: .leading, spacing: 3) {
                Text(recording.title.isEmpty ? "Gravação" : recording.title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.96))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let duration = recording.duration, !duration.isEmpty {
                        Text(duration)
                            .font(.system(size: 11))
                            .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                    }

                    if let detail = recording.detail, !detail.isEmpty {
                        Circle()
                            .fill(TealColors.accent.opacity(0.40))
                            .frame(width: 3, height: 3)
                        Text(detail)
                            .font(.system(size: 11))
                            .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                    }

                    if let date = recording.date, !date.isEmpty {
                        Circle()
                            .fill(TealColors.accent.opacity(0.40))
                            .frame(width: 3, height: 3)
                        Text(date)
                            .font(.system(size: 11))
                            .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                    }
                }
            }

            Spacer()

            // Status badge
            TranscricaoStatusBadge(status: displayStatus)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(TealColors.cardBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(TealColors.accent.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.50), radius: 20, y: 10)
        .shadow(color: TealColors.accent.opacity(0.07), radius: 14)
    }
}
