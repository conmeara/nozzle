import AppKit
import UniformTypeIdentifiers
import CryptoKit
import Observation

@Observable @MainActor
final class FileSystemSource: ContentSource {
    let id: String
    let name: String
    let icon: NSImage
    let type: ContentSourceType = .folder
    private let folderURL: URL
    private var cachedItems: [ContentItem] = []
    
    var isMonitoring: Bool = false
    var searchQuery: String = ""
    
    init(folderURL: URL) {
        self.folderURL = folderURL
        self.id = "folder:\(folderURL.path)"
        self.name = folderURL.lastPathComponent
        self.icon = NSWorkspace.shared.icon(forFile: folderURL.path)
    }
    
    var items: [ContentItem] {
        if searchQuery.isEmpty { return cachedItems }
        return search(query: searchQuery)
    }
    
    func startMonitoring() {
        // Phase 2: Will implement FSEvents monitoring
        isMonitoring = true
    }
    
    func stopMonitoring() {
        // Phase 2: Will stop FSEvents monitoring
        isMonitoring = false
    }
    
    func refresh() async {
        // Scan directory off main thread
        let task = Task.detached { [folderURL] () -> [ContentItem] in
            let fm = FileManager.default
            guard let urls = try? fm.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { return [] }
            
            let items = urls.compactMap { url -> ContentItem? in
                guard let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey]),
                      resourceValues.isDirectory != true else { return nil }
                
                let modDate = resourceValues.contentModificationDate ?? Date.distantPast
                let stableIdString = "\(url.absoluteString):\(modDate.timeIntervalSince1970)"
                let hash = SHA256.hash(data: Data(stableIdString.utf8))
                let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
                let truncatedHash = String(hashString.prefix(32))
                let formattedHash = truncatedHash.inserting("-", at: [8, 12, 16, 20])
                let uuid = UUID(uuidString: formattedHash) ?? UUID()
                
                return ContentItem(
                    id: uuid,
                    title: url.lastPathComponent,
                    timestamp: modDate,
                    sourceType: .folder,
                    sourceId: "folder:\(folderURL.path)",
                    fileURL: url,
                    plainText: url.path
                )
            }
            
            return items.sorted { $0.timestamp > $1.timestamp }
        }
        
        let items = await task.value
        self.cachedItems = items
    }
    
    func search(query: String) -> [ContentItem] {
        cachedItems.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            ($0.plainText ?? "").localizedCaseInsensitiveContains(query)
        }
    }
}

// Helper extension to insert separators into a string
private extension String {
    func inserting(_ separator: String, at indices: [Int]) -> String {
        var result = self
        for (offset, index) in indices.enumerated() {
            let actualIndex = self.index(self.startIndex, offsetBy: index + offset * separator.count)
            result.insert(contentsOf: separator, at: actualIndex)
        }
        return result
    }
}