import AppKit
import Observation

@Observable @MainActor
final class ContentManager {
    static let shared = ContentManager()
    
    private(set) var sources: [String: any ContentSource] = [:]
    private(set) var orderedSourceIds: [String] = []
    var activeSourceId: String = "clipboard"   // default tab
    
    // Phase 2: Centralized selection
    private(set) var selectedItemIds: Set<UUID> = []
    
    // Preview focus tracking
    private(set) var focusedItemId: UUID?
    
    var selectedItems: [ContentItem] {
        allItems.filter { selectedItemIds.contains($0.id) }
    }
    
    var focusedContentItem: ContentItem? {
        allItems.first { $0.id == focusedItemId }
    }
    
    var allItems: [ContentItem] {
        orderedSourceIds.flatMap { sources[$0]?.items ?? [] }
    }
    
    // Computed views
    var activeItems: [ContentItem] {
        guard let src = sources[activeSourceId] else { return [] }
        return src.items
    }
    
    // Selection management
    func toggleSelection(_ id: UUID) {
        if selectedItemIds.remove(id) == nil {
            selectedItemIds.insert(id)
        }
        // Bridge to clipboard selection if needed
        syncClipboardSelection(id)
    }
    
    func clearSelection() {
        selectedItemIds.removeAll()
        // Also clear clipboard selection
        if let clipboardSource = sources["clipboard"] as? ClipboardSource {
            History.shared.items.forEach { $0.isSelected = false }
        }
    }
    
    func isSelected(_ id: UUID) -> Bool {
        selectedItemIds.contains(id)
    }
    
    func focus(_ id: UUID?) {
        focusedItemId = id
    }
    
    private func syncClipboardSelection(_ id: UUID) {
        // If this is a clipboard item, sync with History
        if let item = allItems.first(where: { $0.id == id }),
           item.sourceType == .clipboard {
            if let historyItem = History.shared.items.first(where: { $0.id == id }) {
                historyItem.isSelected = selectedItemIds.contains(id)
            }
        }
    }
    
    // Registration
    func registerSource<T: ContentSource>(_ source: T) {
        sources[source.id] = source
        if !orderedSourceIds.contains(source.id) {
            orderedSourceIds.append(source.id)
        }
    }
    
    // Lookup
    func getAllSources() -> [any ContentSource] {
        orderedSourceIds.compactMap { sources[$0] }
    }
    
    func getItems(for sourceId: String) -> [ContentItem] {
        sources[sourceId]?.items ?? []
    }
    
    // Search
    func searchAcrossAllSources(query: String) -> [ContentItem] {
        sources.values.flatMap { $0.search(query: query) }
    }
}