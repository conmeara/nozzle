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
        let wasSelected = selectedItemIds.contains(id)
        
        if wasSelected {
            selectedItemIds.remove(id)
            // If it's a folder, also deselect all its children
            deselectFolderChildren(id)
        } else {
            selectedItemIds.insert(id)
            // If it's a folder, also select all its visible children
            selectFolderChildren(id)
        }
        
        // Bridge to clipboard selection if needed
        syncClipboardSelection(id)
    }
    
    private func selectFolderChildren(_ folderId: UUID) {
        guard let folderItem = allItems.first(where: { $0.id == folderId }),
              folderItem.isFolder,
              let folderPath = folderItem.fileURL?.path else { return }
        
        // Select all visible children of this folder
        for item in allItems {
            if item.parentPath == folderPath {
                selectedItemIds.insert(item.id)
                // Recursively select nested folder children
                if item.isFolder {
                    selectFolderChildren(item.id)
                }
            }
        }
    }
    
    private func deselectFolderChildren(_ folderId: UUID) {
        guard let folderItem = allItems.first(where: { $0.id == folderId }),
              folderItem.isFolder,
              let folderPath = folderItem.fileURL?.path else { return }
        
        // Deselect all children of this folder
        for item in allItems {
            if item.parentPath == folderPath {
                selectedItemIds.remove(item.id)
                // Recursively deselect nested folder children
                if item.isFolder {
                    deselectFolderChildren(item.id)
                }
            }
        }
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
    
    // Removal
    func removeSource(_ sourceId: String) {
        guard let source = sources[sourceId] else { return }
        
        // Stop monitoring before removal
        source.stopMonitoring()
        
        // Remove from storage
        sources.removeValue(forKey: sourceId)
        orderedSourceIds.removeAll { $0 == sourceId }
        
        // Clear any selections from this source
        let sourceItems = source.items
        for item in sourceItems {
            selectedItemIds.remove(item.id)
        }
        
        // If this was the active source, switch to clipboard
        if activeSourceId == sourceId {
            activeSourceId = "clipboard"
        }
        
        // Clean up focused item if it was from this source
        if let focusedId = focusedItemId,
           sourceItems.contains(where: { $0.id == focusedId }) {
            focusedItemId = nil
        }
        
        // For folder sources, also remove the bookmark
        if source.type == .folder,
           let fileSystemSource = source as? FileSystemSource {
            // Extract folder URL from source ID
            let folderPath = String(sourceId.dropFirst("folder:".count))
            let folderURL = URL(fileURLWithPath: folderPath)
            Bookmarks.remove(url: folderURL)
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