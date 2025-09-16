import AppKit
import Observation

@Observable @MainActor
final class ClipboardSource: ContentSource {
    let id = "clipboard"
    let name = "Clipboard"
    let icon = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard")!
    let type: ContentSourceType = .clipboard
    
    private let history: History = History.shared      // existing model
    @ObservationIgnored private var cachedItems: [ContentItem] = []
    @ObservationIgnored private var cachedVersion: Int = -1
    var isMonitoring: Bool { true }                    // handled by Clipboard itself
    var searchQuery: String {
        get { history.searchQuery }
        set { history.searchQuery = newValue }          // leverage existing search
    }
    
    var items: [ContentItem] {
        let version = history.itemsRevision
        if version != cachedVersion {
            cachedItems = history.items.map { decorator in
                // Get UTI for file URLs to enable proper file type badges
                let uniformTypeIdentifier: String? = {
                    if let fileURL = decorator.item.fileURLs.first,
                       let resourceValues = try? fileURL.resourceValues(forKeys: [.contentTypeKey]),
                       let contentType = resourceValues.contentType {
                        return contentType.identifier
                    }
                    return nil
                }()
                
                return ContentItem(
                    id: decorator.id,
                    title: decorator.title,
                    timestamp: decorator.item.lastCopiedAt,
                    sourceType: .clipboard,
                    sourceId: id,
                    fileURL: decorator.item.fileURLs.first,
                    imageData: decorator.item.imageData,
                    rtfData: decorator.item.rtfData,
                    htmlData: decorator.item.htmlData,
                    plainText: decorator.item.text,
                    uniformTypeIdentifier: uniformTypeIdentifier,
                    applicationBundleId: decorator.item.application,
                    isSelected: decorator.isSelected,
                    isVisible: decorator.isVisible
                )
            }
            cachedVersion = version
        }
        return cachedItems
    }
    
    func startMonitoring() {
        // Already handled by Clipboard
    }
    
    func stopMonitoring() {
        // Already handled by Clipboard
    }
    
    func refresh() async {
        // Clipboard refreshes automatically
    }
    
    func search(query: String) -> [ContentItem] {
        items.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }
}
