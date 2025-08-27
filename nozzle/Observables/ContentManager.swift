import AppKit
import Observation

enum FolderSelectionState {
    case none     // No children selected
    case partial  // Some children selected
    case all      // All children selected
}

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
        let items = allItems.filter { selectedItemIds.contains($0.id) }
        
        // Add parent folders when their children are selected
        var parentFolders: [ContentItem] = []
        
        for selectedItem in items {
            if let parentPath = selectedItem.parentPath {
                // Find the parent folder
                if let parentFolder = allItems.first(where: { 
                    $0.isFolder && $0.fileURL?.path == parentPath 
                }) {
                    // Add parent if not already selected explicitly and not already in our list
                    if !selectedItemIds.contains(parentFolder.id) && 
                       !parentFolders.contains(where: { $0.id == parentFolder.id }) {
                        parentFolders.append(parentFolder)
                    }
                }
            }
        }
        
        // Combine selected items and their parent folders, with parents first
        let result = parentFolders + items
        
        // Sort to ensure logical order: parents before children
        return result.sorted { first, second in
            // If one is parent of the other, parent comes first
            if let firstPath = first.fileURL?.path,
               second.parentPath == firstPath {
                return true // first is parent of second
            }
            if let secondPath = second.fileURL?.path,
               first.parentPath == secondPath {
                return false // second is parent of first
            }
            // Otherwise maintain original timestamp order
            return first.timestamp > second.timestamp
        }
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
        // Check if this is a folder and handle specially
        if let folderItem = allItems.first(where: { $0.id == id }), folderItem.isFolder {
            toggleFolderSelection(id)
        } else {
            // Regular item selection
            let wasSelected = selectedItemIds.contains(id)
            if wasSelected {
                selectedItemIds.remove(id)
            } else {
                selectedItemIds.insert(id)
            }
            // Bridge to clipboard selection if needed
            syncClipboardSelection(id)
        }
    }
    
    private func toggleFolderSelection(_ folderId: UUID) {
        guard let folderItem = allItems.first(where: { $0.id == folderId }),
              folderItem.isFolder,
              let folderPath = folderItem.fileURL?.path else { return }
        
        let children = allItems.filter { $0.parentPath == folderPath }
        let currentState = getFolderSelectionState(folderId)
        
        
        switch currentState {
        case .none:
            // No children selected - select everything
            if children.isEmpty {
                // Collapsed folder - select the folder itself
                selectedItemIds.insert(folderId)
            } else {
                // Expanded folder - select all children
                selectFolderChildren(folderId)
            }
            
        case .partial:
            // Some children selected - deselect everything
            if children.isEmpty {
                // Collapsed folder - deselect the folder itself
                selectedItemIds.remove(folderId)
            } else {
                // Expanded folder - deselect all children
                deselectFolderChildren(folderId)
            }
            
        case .all:
            // Everything selected - deselect everything
            if children.isEmpty {
                // Collapsed folder - deselect the folder itself
                selectedItemIds.remove(folderId)
            } else {
                // Expanded folder - deselect all children
                deselectFolderChildren(folderId)
            }
        }
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
        
        // Also select the folder itself (for consistency when expanding/collapsing)
        selectedItemIds.insert(folderId)
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
        
        // Also deselect the folder itself
        selectedItemIds.remove(folderId)
    }
    
    func clearSelection() {
        selectedItemIds.removeAll()
        // Also clear clipboard selection (boolean test only)
        if sources["clipboard"] is ClipboardSource {
            History.shared.items.forEach { $0.isSelected = false }
        }
    }
    
    func isSelected(_ id: UUID) -> Bool {
        selectedItemIds.contains(id)
    }
    
    func getFolderSelectionState(_ folderId: UUID) -> FolderSelectionState {
        guard let folderItem = allItems.first(where: { $0.id == folderId }),
              folderItem.isFolder,
              let folderPath = folderItem.fileURL?.path else { return .none }
        
        // Get all visible children of this folder
        let children = allItems.filter { $0.parentPath == folderPath }
        
        // If folder is collapsed (no visible children), check if folder itself is selected
        if children.isEmpty {
            return selectedItemIds.contains(folderId) ? .all : .none
        }
        
        // For expanded folders, calculate based on children selection
        let selectedChildren = children.filter { selectedItemIds.contains($0.id) }
        
        if selectedChildren.count == 0 {
            return .none
        } else if selectedChildren.count == children.count {
            return .all
        } else {
            return .partial
        }
    }
    
    func focus(_ id: UUID?) {
        focusedItemId = id
    }
    
    // Called after folder expansion to handle selected folder states
    func handleFolderExpansion(_ folderPath: String) {
        // Find the folder by path
        guard let folderItem = allItems.first(where: { 
            $0.isFolder && $0.fileURL?.path == folderPath 
        }) else { return }
        
        // If the folder itself is selected, select all its newly visible children
        if selectedItemIds.contains(folderItem.id) {
            selectFolderChildren(folderItem.id)
        }
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
        if source.type == .folder {
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
