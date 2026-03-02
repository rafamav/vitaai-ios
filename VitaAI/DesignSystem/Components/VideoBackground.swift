import SwiftUI
import AVFoundation

// MARK: - VideoBackground

/// Full-screen muted looping video background.
///
/// Mirrors Android VideoBackground (ExoPlayer REPEAT_MODE_ONE, volume=0,
/// SCALE_TO_FIT_WITH_CROPPING). Uses AVPlayer with AVPlayerLayer on iOS.
///
/// Usage:
/// ```swift
/// VideoBackground(resourceName: "onboarding_bg", fileExtension: "mp4")
///     .ignoresSafeArea()
/// ```
struct VideoBackground: View {
    /// Name of the video resource inside the app bundle (without extension).
    let resourceName: String
    /// File extension, e.g. "mp4" or "mov". Defaults to "mp4".
    var fileExtension: String = "mp4"

    var body: some View {
        _AVPlayerView(resourceName: resourceName, fileExtension: fileExtension)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
    }
}

// MARK: - _AVPlayerView (UIViewRepresentable)

private struct _AVPlayerView: UIViewRepresentable {
    let resourceName: String
    let fileExtension: String

    func makeUIView(context: Context) -> _VideoContainerView {
        let view = _VideoContainerView()
        view.configure(resourceName: resourceName, fileExtension: fileExtension)
        return view
    }

    func updateUIView(_ uiView: _VideoContainerView, context: Context) {}

    static func dismantleUIView(_ uiView: _VideoContainerView, coordinator: ()) {
        uiView.teardown()
    }
}

// MARK: - _VideoContainerView

private final class _VideoContainerView: UIView {
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var loopObserver: NSObjectProtocol?

    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var avPlayerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    func configure(resourceName: String, fileExtension: String) {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: fileExtension) else {
            return
        }

        let item = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.isMuted = true
        avPlayer.allowsExternalPlayback = false

        avPlayerLayer.player = avPlayer
        avPlayerLayer.videoGravity = .resizeAspectFill

        // Loop playback
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak avPlayer] _ in
            avPlayer?.seek(to: .zero)
            avPlayer?.play()
        }

        avPlayer.play()
        self.player = avPlayer
    }

    func teardown() {
        player?.pause()
        if let obs = loopObserver {
            NotificationCenter.default.removeObserver(obs)
        }
        player = nil
        avPlayerLayer.player = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        avPlayerLayer.frame = bounds
    }

    deinit { teardown() }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ZStack {
        // No actual video file in preview — shows black background
        VideoBackground(resourceName: "sample", fileExtension: "mp4")
        Text("VideoBackground")
            .foregroundColor(VitaColors.textPrimary)
            .font(VitaTypography.titleLarge)
    }
}
#endif
