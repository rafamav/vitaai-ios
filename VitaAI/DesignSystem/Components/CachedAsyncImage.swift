import SwiftUI

/// AsyncImage replacement with memory + disk cache.
/// Prevents profile photos from flickering/disappearing on re-render.
struct CachedAsyncImage<Placeholder: View>: View {
    let url: URL?
    let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var isLoading = false

    init(url: URL?, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url, image == nil else { return }
            await loadImage(from: url)
        }
    }

    private func loadImage(from url: URL) async {
        // 1. Check memory cache
        if let cached = ImageCache.shared.get(for: url) {
            self.image = cached
            return
        }

        // 2. Check disk cache
        if let diskData = ImageCache.shared.readDisk(for: url),
           let diskImage = UIImage(data: diskData) {
            ImageCache.shared.set(diskImage, for: url)
            self.image = diskImage
            return
        }

        // 3. Download
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  let downloaded = UIImage(data: data) else { return }

            ImageCache.shared.set(downloaded, for: url)
            ImageCache.shared.writeDisk(data, for: url)
            self.image = downloaded
        } catch {
            // Silent fail — placeholder stays visible
        }
    }
}

// MARK: - Image Cache (memory + disk)

final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()

    private let memory = NSCache<NSString, UIImage>()
    private let diskDir: URL

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskDir = caches.appendingPathComponent("vita_image_cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskDir, withIntermediateDirectories: true)
        memory.countLimit = 50
    }

    func get(for url: URL) -> UIImage? {
        memory.object(forKey: url.absoluteString as NSString)
    }

    func set(_ image: UIImage, for url: URL) {
        memory.setObject(image, forKey: url.absoluteString as NSString)
    }

    func readDisk(for url: URL) -> Data? {
        try? Data(contentsOf: diskPath(for: url))
    }

    func writeDisk(_ data: Data, for url: URL) {
        try? data.write(to: diskPath(for: url))
    }

    private func diskPath(for url: URL) -> URL {
        let hash = url.absoluteString.data(using: .utf8)!
            .map { String(format: "%02x", $0) }.joined()
            .suffix(40)
        return diskDir.appendingPathComponent(String(hash))
    }
}
