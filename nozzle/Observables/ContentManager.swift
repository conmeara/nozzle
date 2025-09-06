import AppKit
import UniformTypeIdentifiers
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
    // Remember the last non-Prompts source so we can return after picking a prompt
    var lastNonPromptsSourceId: String = "clipboard"
    
    // Phase 2: Centralized selection
    private(set) var selectedItemIds: Set<UUID> = []
    // Subset of selected items that are marked as examples
    private(set) var exampleItemIds: Set<UUID> = []
    
    // Preview focus tracking
    private(set) var focusedItemId: UUID?
    
    // Cache for selected items to avoid repeated full scans and sorts
    @ObservationIgnored private var _selectedCache: [ContentItem] = []
    @ObservationIgnored private var _selectedCacheDirty: Bool = true
    
    var selectedItems: [ContentItem] {
        if _selectedCacheDirty {
            _selectedCache = makeSelectedItems()
            _selectedCacheDirty = false
        }
        return _selectedCache
    }
    
    // Convenience: selected items split into context vs examples
    var selectedContextItems: [ContentItem] {
        selectedItems.filter { !exampleItemIds.contains($0.id) }
    }
    
    var selectedExampleItems: [ContentItem] {
        selectedItems.filter { exampleItemIds.contains($0.id) }
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
                // Clear example state if deselected
                exampleItemIds.remove(id)
            } else {
                selectedItemIds.insert(id)
            }
            // Bridge to clipboard selection if needed
            syncClipboardSelection(id)
        }
        markSelectedDirty()
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
        markSelectedDirty()
    }
    
    func selectFolderChildren(_ folderId: UUID) {
        guard let folderItem = allItems.first(where: { $0.id == folderId }),
              folderItem.isFolder,
              let folderPath = folderItem.fileURL?.path else { return }
        
        // Select all visible children of this folder
        for item in allItems {
            if item.parentPath == folderPath {
                selectedItemIds.insert(item.id)
                // Children are selected as context by default (not examples)
                exampleItemIds.remove(item.id)
                // Recursively select nested folder children
                if item.isFolder {
                    selectFolderChildren(item.id)
                }
            }
        }
        
        // Also select the folder itself (for consistency when expanding/collapsing)
        selectedItemIds.insert(folderId)
        exampleItemIds.remove(folderId)
        markSelectedDirty()
    }
    
    func deselectFolderChildren(_ folderId: UUID) {
        guard let folderItem = allItems.first(where: { $0.id == folderId }),
              folderItem.isFolder,
              let folderPath = folderItem.fileURL?.path else { return }
        
        // Deselect all children of this folder
        for item in allItems {
            if item.parentPath == folderPath {
                selectedItemIds.remove(item.id)
                // Remove example flag when deselecting children
                exampleItemIds.remove(item.id)
                // Recursively deselect nested folder children
                if item.isFolder {
                    deselectFolderChildren(item.id)
                }
            }
        }
        
        // Also deselect the folder itself
        selectedItemIds.remove(folderId)
        exampleItemIds.remove(folderId)
        markSelectedDirty()
    }
    
    func clearSelection() {
        selectedItemIds.removeAll()
        exampleItemIds.removeAll()
        // Also clear clipboard selection (boolean test only)
        if sources["clipboard"] is ClipboardSource {
            History.shared.items.forEach { $0.isSelected = false }
        }
        markSelectedDirty()
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
        markSelectedDirty()
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
        // Cleanup persisted FSEvents last-id for this source
        UserDefaults.standard.removeObject(forKey: "FSEvents.lastId.\(source.id)")
        
        // Remove from storage
        sources.removeValue(forKey: sourceId)
        orderedSourceIds.removeAll { $0 == sourceId }
        
        // Clear any selections from this source
        let sourceItems = source.items
        for item in sourceItems {
            selectedItemIds.remove(item.id)
            exampleItemIds.remove(item.id)
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
            // Prefer obtaining the exact URL from FileSystemSource
            if let fs = source as? FileSystemSource {
                Bookmarks.remove(url: fs.folderURL)
            } else if sourceId.hasPrefix("folder:") {
                // Fallback: extract folder URL from identifier pattern
                let folderPath = String(sourceId.dropFirst("folder:".count))
                let folderURL = URL(fileURLWithPath: folderPath)
                Bookmarks.remove(url: folderURL)
            }
        }
        markSelectedDirty()
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
    
    // MARK: - Example state
    func isExample(_ id: UUID) -> Bool {
        exampleItemIds.contains(id)
    }
    
    func toggleExample(_ id: UUID) {
        // Allow toggling example state for any textual items (no need to be selected as context)
        guard isTextualItem(id) else { return }
        guard let item = allItems.first(where: { $0.id == id }) else { return }
        if exampleItemIds.contains(id) {
            // Turning OFF example: clear on folder and its descendants
            exampleItemIds.remove(id)
            if item.isFolder {
                let childIDs = descendantTextItemIDs(for: item)
                for cid in childIDs {
                    exampleItemIds.remove(cid)
                }
            }
        } else {
            // Turning ON example
            exampleItemIds.insert(id)
            if item.isFolder {
                // Select and mark all textual descendants as examples (even if collapsed)
                let childIDs = descendantTextItemIDs(for: item)
                for cid in childIDs {
                    selectedItemIds.insert(cid)
                    exampleItemIds.insert(cid)
                }
            }
        }
        markSelectedDirty()
    }
    
    // Collect all textual descendant file UUIDs for a folder item by scanning the filesystem
    private func descendantTextItemIDs(for folder: ContentItem) -> [UUID] {
        guard folder.isFolder, let baseURL = folder.fileURL else { return [] }
        let fileURLs = self.enumerateDescendantFiles(at: baseURL)
        var ids: [UUID] = []
        for url in fileURLs {
            if isTextURL(url) {
                let id = stableUUID(for: url)
                ids.append(id)
            }
        }
        return ids
    }
    
    // File enumeration helpers
    private func enumerateDescendantFiles(at baseURL: URL) -> [URL] {
        var results: [URL] = []
        let fm = FileManager.default
        if let enumerator = fm.enumerator(at: baseURL, includingPropertiesForKeys: [.isDirectoryKey, .contentTypeKey], options: [.skipsHiddenFiles]) {
            for case let url as URL in enumerator {
                do {
                    let vals = try url.resourceValues(forKeys: [.isDirectoryKey])
                    if vals.isDirectory == true { continue }
                    results.append(url)
                } catch {
                    continue
                }
            }
        }
        return results
    }
    
    private func isTextURL(_ url: URL) -> Bool {
        let type = FileSystemSource.resolvedType(for: url)
        if type?.conforms(to: .text) == true { return true }
        if type == .rtf || type == .rtfd || type == .html { return true }
        // Markdown special cases
        if type?.identifier == "net.daringfireball.markdown" ||
           type?.identifier == "public.markdown" ||
           type?.preferredFilenameExtension == "md" { return true }
        return false
    }
    
    private func stableUUID(for url: URL) -> UUID {
        let snap = FileIdentity.snapshot(for: url)
        return FileSystemSource.makeStableUUID(identity: snap.identity, fallbackPath: url.absoluteString)
    }
    
    func canToggleExample(_ id: UUID) -> Bool {
        guard selectedItemIds.contains(id),
              let _ = allItems.first(where: { $0.id == id }) else { return false }
        
        return isTextualItem(id)
    }
    
    func isTextualItem(_ id: UUID) -> Bool {
        guard let item = allItems.first(where: { $0.id == id }) else { return false }
        
        if item.isFolder {
            // Allow folder examples only if all descendant files are textual and there is at least one file
            guard let baseURL = item.fileURL else { return false }
            let files = enumerateDescendantFiles(at: baseURL)
            let textual = files.filter { isTextURL($0) }
            guard !files.isEmpty else { return false }
            return files.count == textual.count
        }
        
        // Disallow media or non-text files as examples
        if item.imageData != nil { return false }
        if let _ = item.fileURL, !item.isText { return false }
        
        // Text files are allowed; general files only if UTType is text
        if let _ = item.fileURL {
            return item.isText
        }
        // Clipboard/memory items: require textual content
        if item.plainText != nil { return true }
        if item.rtfData != nil { return true }
        if item.htmlData != nil { return true }
        return false
    }
}

// MARK: - Selected items caching helpers
extension ContentManager {
    func markSelectedDirty() {
        _selectedCacheDirty = true
    }
    
    private func makeSelectedItems() -> [ContentItem] {
        let items = allItems
        guard !selectedItemIds.isEmpty, !items.isEmpty else { return [] }
        
        // Index folders by path for fast parent lookup
        var folderByPath: [String: ContentItem] = [:]
        folderByPath.reserveCapacity(items.count)
        for item in items where item.isFolder {
            if let path = item.fileURL?.path { folderByPath[path] = item }
        }
        
        // Determine which parent folders need to be included due to selected children
        var neededParentIds: Set<UUID> = []
        for item in items {
            guard selectedItemIds.contains(item.id) else { continue }
            if let parentPath = item.parentPath, let parent = folderByPath[parentPath] {
                if !selectedItemIds.contains(parent.id) {
                    neededParentIds.insert(parent.id)
                }
            }
        }
        
        // Build result with better hierarchical grouping
        var result: [ContentItem] = []
        result.reserveCapacity(selectedItemIds.count + neededParentIds.count)
        var seen: Set<UUID> = []
        
        // Process items in hierarchical order: folders followed immediately by their children
        for item in items {
            // Add folders (both needed parents and explicitly selected)
            if item.isFolder && (neededParentIds.contains(item.id) || selectedItemIds.contains(item.id)) {
                if !seen.contains(item.id) {
                    result.append(item)
                    seen.insert(item.id)
                    
                    // Immediately add children of this folder that are selected
                    let folderPath = item.fileURL?.path
                    for childItem in items {
                        if selectedItemIds.contains(childItem.id) && 
                           !seen.contains(childItem.id) && 
                           childItem.parentPath == folderPath {
                            result.append(childItem)
                            seen.insert(childItem.id)
                        }
                    }
                }
            }
        }
        
        // Add any remaining selected items that don't have a parent (e.g., clipboard items)
        for item in items {
            if selectedItemIds.contains(item.id) && !seen.contains(item.id) {
                result.append(item)
                seen.insert(item.id)
            }
        }
        
        return result
    }
}
