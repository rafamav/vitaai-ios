import SwiftUI

// MARK: - PdfAudioPlaybackOverlay
//
// Pílula flutuante mostrada quando há áudio gravado/gravando neste PDF. Visual:
// - Recording: ícone mic.fill pulsante vermelho + tempo decorrido + Stop.
// - Loaded: play + slider de progresso + tempo + close.
// - Playing: pause + slider + tempo + close.
//
// Posicionamento: bottom center, acima do PDF. Não bloqueia o conteúdo. Mesma
// linguagem visual da toolbar (ultraThinMaterial + gold accent).

struct PdfAudioPlaybackOverlay: View {
    @Bindable var recorder: PdfAudioRecorder
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            switch recorder.state {
            case .idle:
                idleControls
            case .recording:
                recordingControls
            case .loaded, .paused:
                playbackControls(showPause: false)
            case .playing:
                playbackControls(showPause: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(glassBackground)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(VitaColors.accent.opacity(0.5), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 14, y: 4)
    }

    // MARK: - States

    @ViewBuilder
    private var idleControls: some View {
        Button(action: onStartRecording) {
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .font(VitaTypography.titleSmall.weight(.semibold))
                Text("Gravar aula")
                    .font(VitaTypography.labelMedium)
            }
            .foregroundStyle(VitaColors.accent)
        }
        .buttonStyle(.plain)

        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(VitaTypography.titleSmall.weight(.semibold))
                .foregroundStyle(VitaColors.textSecondary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var recordingControls: some View {
        Image(systemName: "circle.fill")
            .font(VitaTypography.labelSmall)
            .foregroundStyle(VitaColors.recording)
            .symbolEffect(.pulse.byLayer, options: .repeating)

        Text(formatTime(recorder.currentTime))
            .font(VitaTypography.labelMedium)
            .foregroundStyle(VitaColors.textPrimary)
            .monospacedDigit()

        Text("Gravando…")
            .font(VitaTypography.labelSmall)
            .foregroundStyle(VitaColors.textTertiary)

        Button(action: onStopRecording) {
            Image(systemName: "stop.circle.fill")
                .font(VitaTypography.headlineMedium)
                .foregroundStyle(VitaColors.recording)
                .symbolRenderingMode(.hierarchical)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Parar gravação")
    }

    @ViewBuilder
    private func playbackControls(showPause: Bool) -> some View {
        Button {
            if showPause { recorder.pausePlayback() } else { recorder.startPlayback() }
        } label: {
            Image(systemName: showPause ? "pause.fill" : "play.fill")
                .font(VitaTypography.titleMedium.weight(.semibold))
                .foregroundStyle(VitaColors.accent)
                .frame(width: 32, height: 32)
                .background(VitaColors.accent.opacity(0.15), in: Circle())
        }
        .buttonStyle(.plain)

        Text(formatTime(recorder.currentTime))
            .font(VitaTypography.labelSmall)
            .foregroundStyle(VitaColors.textSecondary)
            .monospacedDigit()

        // Custom slider (Slider native não combina com glass).
        progressBar
            .frame(width: 140, height: 6)

        Text(formatTime(recorder.totalDuration))
            .font(VitaTypography.labelSmall)
            .foregroundStyle(VitaColors.textTertiary)
            .monospacedDigit()

        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(VitaTypography.titleSmall.weight(.semibold))
                .foregroundStyle(VitaColors.textSecondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Progress bar

    @ViewBuilder
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(VitaColors.glassBorder.opacity(0.3))

                Capsule()
                    .fill(VitaColors.accent)
                    .frame(width: progressWidth(in: geo.size.width))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let ratio = max(0, min(1, value.location.x / geo.size.width))
                        recorder.seek(to: ratio * recorder.totalDuration)
                    }
            )
        }
    }

    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        guard recorder.totalDuration > 0 else { return 0 }
        let ratio = recorder.currentTime / recorder.totalDuration
        return totalWidth * CGFloat(ratio)
    }

    private func formatTime(_ s: TimeInterval) -> String {
        let total = max(0, Int(s))
        let m = total / 60
        let sec = total % 60
        return String(format: "%d:%02d", m, sec)
    }

    // MARK: - Glass background

    private var glassBackground: some View {
        ZStack {
            Capsule()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
            Capsule()
                .fill(VitaColors.accent.opacity(0.06))
        }
    }
}
