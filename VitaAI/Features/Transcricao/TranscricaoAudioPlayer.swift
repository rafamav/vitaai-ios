import AVFoundation
import Combine
import SwiftUI

/// Manages AVPlayer streaming playback for studio audio sources.
/// Streams authenticated audio from the backend — no local file needed.
@MainActor
final class TranscricaoAudioPlayer: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isLoading = false
    @Published var error: String?

    /// Current word index for karaoke sync (nil if no word timestamps)
    @Published var activeWordIndex: Int?

    /// Playback rate (1.0 normal, 1.25, 1.5, 2.0). Persistido por sessão —
    /// padrão de podcast app (Apple Podcasts, Overcast, Pocket Casts).
    @Published var playbackRate: Float = 1.0 {
        didSet { player?.rate = isPlaying ? playbackRate : 0 }
    }

    /// Skip silence — pula trechos onde não há fala. Implementação leve via
    /// detector de palavra atual: se não há palavra ativa por >1.2s, salta
    /// pra próxima word.start. Sem reanalise do audio (custaria GPU+RAM).
    @Published var skipSilenceEnabled: Bool = false

    /// Última palavra ativa (pra detectar gap de silêncio entre palavras).
    private var lastActiveWordTime: Double = 0

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var words: [WhisperWord] = []

    deinit {
        if let observer = timeObserver, let player {
            player.removeTimeObserver(observer)
        }
        player?.pause()
        statusObserver?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public

    /// Prepare audio from a presigned R2 GET URL (gold standard — no backend
    /// roundtrip needed, backend attaches the URL to the source metadata).
    func prepareFromUrl(_ signedUrl: String, words: [WhisperWord] = []) {
        cleanup()
        self.words = words
        isLoading = true
        error = nil

        guard let url = URL(string: signedUrl) else {
            error = "URL inválida"
            isLoading = false
            return
        }
        let asset = AVURLAsset(url: url)
        setupPlayer(with: asset)
    }

    /// Prepare audio from R2 via /api/files/:id/download (gold standard)
    func prepareFromFileId(fileId: String, tokenStore: TokenStore, words: [WhisperWord] = []) {
        cleanup()
        self.words = words
        isLoading = true
        error = nil

        // First fetch the presigned download URL, then stream from R2 directly
        Task {
            let token = await tokenStore.token
            let downloadEndpoint = AppConfig.apiBaseURL + "/files/\(fileId)/download"
            guard let endpointURL = URL(string: downloadEndpoint) else {
                error = "URL inválida"
                isLoading = false
                return
            }

            var request = URLRequest(url: endpointURL)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            if let t = token {
                request.setValue("__Secure-better-auth.session_token=\(t)", forHTTPHeaderField: "Cookie")
            }

            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                struct DownloadResponse: Decodable { let url: String }
                let resp = try JSONDecoder().decode(DownloadResponse.self, from: data)
                guard let r2URL = URL(string: resp.url) else {
                    error = "URL R2 inválida"
                    isLoading = false
                    return
                }
                // Stream directly from R2 presigned URL (no auth needed)
                let asset = AVURLAsset(url: r2URL)
                setupPlayer(with: asset)
            } catch {
                self.error = "Erro ao buscar áudio: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    /// Prepare audio from legacy /studio/upload/ endpoint
    func prepare(fileName: String, tokenStore: TokenStore, words: [WhisperWord] = []) {
        cleanup()
        self.words = words
        isLoading = true
        error = nil

        let audioURL = AppConfig.apiBaseURL + "/studio/upload/" + fileName
        guard let url = URL(string: audioURL) else {
            error = "URL inválida"
            isLoading = false
            return
        }

        // Create asset with auth headers
        Task {
            let token = await tokenStore.token
            var headers: [String: String] = [:]
            if let t = token {
                headers["Cookie"] = "__Secure-better-auth.session_token=\(t)"
            }
            let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
            setupPlayer(with: asset)
        }
    }

    private func setupPlayer(with asset: AVURLAsset) {
        let item = AVPlayerItem(asset: asset)
        let avPlayer = AVPlayer(playerItem: item)

        // Configure audio session
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)

        self.player = avPlayer

        // Observe status
        self.statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    self.isLoading = false
                    self.duration = item.duration.seconds.isNaN ? 0 : item.duration.seconds
                case .failed:
                    self.isLoading = false
                    self.error = item.error?.localizedDescription ?? "Erro ao carregar áudio"
                default:
                    break
                }
            }
        }

        // Time observer — every 50ms for smooth karaoke
        let interval = CMTime(seconds: 0.05, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        self.timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                let t = time.seconds
                if !t.isNaN {
                    self.currentTime = t
                    self.updateActiveWord(at: t)
                }
            }
        }

        // End of playback
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isPlaying = false
                self?.player?.seek(to: .zero)
                self?.currentTime = 0
                self?.activeWordIndex = nil
            }
        }
    }

    func togglePlayPause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
            // AVPlayer.play() reset rate pra 1.0 sempre — reaplica o user prefs.
            player.rate = playbackRate
        }
        isPlaying.toggle()
    }

    func seek(to fraction: Double) {
        guard let player, duration > 0 else { return }
        let target = CMTime(seconds: fraction * duration, preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = fraction * duration
        updateActiveWord(at: currentTime)
    }

    func seekToWord(at index: Int) {
        guard index < words.count else { return }
        let time = words[index].start
        guard let player, duration > 0 else { return }
        let target = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
        activeWordIndex = index
        if !isPlaying {
            player.play()
            isPlaying = true
        }
    }

    /// Seek absoluto em segundos (0..duration). Usado pelos timestamps clicáveis
    /// no início de cada segmento da transcrição (Plaud/Otter pattern).
    func seekToTime(_ seconds: Double) {
        guard let player, duration > 0 else { return }
        let clamped = max(0, min(seconds, duration))
        let target = CMTime(seconds: clamped, preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = clamped
        updateActiveWord(at: clamped)
        if !isPlaying {
            player.play()
            isPlaying = true
        }
    }

    // MARK: - Private

    private func updateActiveWord(at time: Double) {
        guard !words.isEmpty else {
            activeWordIndex = nil
            return
        }
        // Binary search for current word
        var lo = 0, hi = words.count - 1
        var best: Int?
        while lo <= hi {
            let mid = (lo + hi) / 2
            if words[mid].start <= time {
                best = mid
                lo = mid + 1
            } else {
                hi = mid - 1
            }
        }
        if let b = best, words[b].end >= time - 0.1 {
            activeWordIndex = b
            lastActiveWordTime = time
        } else if skipSilenceEnabled, isPlaying, let b = best, b + 1 < words.count {
            // Skip silence: se não há palavra ativa há >1.2s e tem palavra
            // próxima, salta pra ela. Heurística simples sem reanalise de
            // audio (zero custo CPU/GPU). Padrão Overcast/Pocket Casts.
            let gap = time - lastActiveWordTime
            let nextStart = words[b + 1].start
            if gap > 1.2, nextStart > time + 0.5 {
                let target = CMTime(seconds: nextStart, preferredTimescale: 600)
                player?.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
                currentTime = nextStart
                activeWordIndex = b + 1
                lastActiveWordTime = nextStart
            }
        }
    }

    private func cleanup() {
        if let observer = timeObserver, let player {
            player.removeTimeObserver(observer)
        }
        timeObserver = nil
        statusObserver?.invalidate()
        statusObserver = nil
        player?.pause()
        player = nil
        NotificationCenter.default.removeObserver(self)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    var currentTimeFormatted: String {
        formatTime(currentTime)
    }

    var durationFormatted: String {
        formatTime(duration)
    }

    private func formatTime(_ t: Double) -> String {
        guard !t.isNaN, t >= 0 else { return "0:00" }
        let mins = Int(t) / 60
        let secs = Int(t) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
