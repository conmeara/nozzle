import SwiftUI
import Foundation

// Simple identity for cache keys: file identity + modDate + size
private final class TextCache {
    static let shared = TextCache()
    private let cache = NSCache<NSString, NSString>()
    private init() { cache.countLimit = 512 }

    func key(for item: ContentItem) -> NSString {
        let idHex = item.fileIdentity?.map { String(format: "%02x", $0) }.joined() ?? "-"
        let mod = item.timestamp.timeIntervalSince1970
        let size = item.fileSize ?? -1
        return NSString(string: "\(idHex)|\(mod)|\(size)")
    }

    func get(_ key: NSString) -> String? { cache.object(forKey: key) as String? }
    func set(_ text: String, for key: NSString) { cache.setObject(NSString(string: text), forKey: key) }
}

struct AsyncTextPreview: View {
    let item: ContentItem
    /// Delay to survive quick hover churn before doing work
    let debounce: TimeInterval = 0.2

    @State private var text: String?
    @State private var isLoading = false
    @State private var loadTask: Task<Void, Never>?

    private var cacheKeyString: String { TextCache.shared.key(for: item) as String }

    var body: some View {
        ZStack {
            if let text {
                // Reuse PlainTextPreview for consistent styling/metadata
                PlainTextPreview(
                    text: text,
                    metadata: PlainTextPreview.PreviewMetadata(
                        application: nil,
                        applicationImage: nil,
                        firstCopiedAt: nil,
                        lastCopiedAt: nil,
                        numberOfCopies: nil,
                        fileName: item.title,
                        fileSize: item.fileSize
                    )
                )
            } else if isLoading {
                // Lightweight placeholder while loading; avoids heavy layout
                VStack(spacing: 8) {
                    ProgressView()
                    if let size = item.fileSize {
                        Text("\(item.title) • \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(item.title).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                // First frame before loading starts (or cache hit)
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text(item.title).font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
        // Tie the task lifecycle to our stable cache key so it cancels on change
        .task(id: cacheKeyString) {
            await load()
        }
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
        }
        .previewSurfaceStyle()
    }

    @MainActor
    private func load() async {
        loadTask?.cancel()
        let key = TextCache.shared.key(for: item)

        if let cached = TextCache.shared.get(key) {
            self.text = cached
            self.isLoading = false
            return
        }

        self.isLoading = true
        // Debounce to avoid work for items that don't "stick"
        loadTask = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(debounce * 1_000_000_000))
                try Task.checkCancellation()

                // Read off the main thread
                let loaded: String = await Task.detached(priority: .utility) {
                    FileContentExtractor.extractPlainText(from: item)
                }.value

                try Task.checkCancellation()
                await MainActor.run {
                    self.isLoading = false
                    TextCache.shared.set(loaded, for: key)
                    self.text = loaded
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.text = ""
                }
            }
        }
        await loadTask?.value
    }
}

