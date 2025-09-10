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
    // Observable version counter to trigger UI updates when selection changes
    private(set) var selectionVersion: Int = 0
    
    // Preview focus tracking
    private(set) var focusedItemId: UUID?
    // Track active inline rename row globally so other clicks can cancel it
    var renameActiveItemId: UUID?
    
    // Pending inline rename request for a specific item id
    var pendingRenameItemId: UUID?
    
    // Prompt editor state tracking for enhanced button integration
    var promptEditorText: String = ""
    var isPromptEditorEditing: Bool = false
    var enhanceButtonClicked: Bool = false // Flag to prevent editor exit on enhance
    
    // Cache for selected items to avoid repeated full scans and sorts
    @ObservationIgnored private var _selectedCache: [ContentItem] = []
    @ObservationIgnored private var _selectedCacheDirty: Bool = true
    
    // Cache for UniversalItemDecorator instances to maintain consistency
    @ObservationIgnored private var _decoratorCache: [String: [UUID: UniversalItemDecorator]] = [:] // sourceId -> [itemId -> decorator]
    @ObservationIgnored private var _decoratorCacheDirty: Set<String> = [] // sourceIds that need cache refresh
    
    // (Removed) Aggregated display version tracking; Aggregated now shows only pasteable items
    
    var selectedItems: [ContentItem] {
        _ = selectionVersion  // Establish dependency for SwiftUI observation
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
    
    func isSelected(_ id: UUID) -> Bool { selectedItemIds.contains(id) }

    // Treat an item as selected if:
    // - It is explicitly selected, or
    // - It is a file inside any selected folder (use path prefix check)
    func isSelected(effectively item: ContentItem) -> Bool {
        if selectedItemIds.contains(item.id) { return true }
        guard item.sourceType == .folder, let itemPath = item.fileURL?.path else { return false }
        // Any selected folder that is an ancestor of this item implies effective selection
        for fid in selectedItemIds {
            if let folder = allItems.first(where: { $0.id == fid && $0.isFolder }),
               let folderPath = folder.fileURL?.path,
               itemPath.hasPrefix(folderPath.hasSuffix("/") ? folderPath : folderPath + "/") {
                // Ensure not the folder itself
                if folder.id != item.id { return true }
            }
        }
        return false
    }
    
    func getFolderSelectionState(_ folderId: UUID) -> FolderSelectionState {
        guard let folderItem = allItems.first(where: { $0.id == folderId }),
              folderItem.isFolder,
              let folderPath = folderItem.fileURL?.path else { return .none }

        // Get all visible children of this folder
        let children = allItems.filter { $0.parentPath == folderPath }

        // If folder is collapsed (no visible children), infer state from real descendants on disk
        if children.isEmpty {
            // If the folder itself is selected, treat as all (effective select)
            if selectedItemIds.contains(folderId) { return .all }
            // Otherwise, compute based on how many descendants are selected
            let urls = enumerateDescendantFiles(at: URL(fileURLWithPath: folderPath))
            guard !urls.isEmpty else { return .none }
            let selectedCount = urls.reduce(0) { acc, url in
                let id = stableUUID(for: url)
                return acc + (selectedItemIds.contains(id) ? 1 : 0)
            }
            if selectedCount == 0 { return .none }
            if selectedCount == urls.count { return .all }
            return .partial
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
    
    // Request inline rename for a newly created/located item by URL (Prompts)
    func requestRename(for url: URL) {
        if let item = sources["prompts"]?.items.first(where: { $0.fileURL == url }) {
            activeSourceId = "prompts"
            focus(item.id)
            pendingRenameItemId = item.id
            renameActiveItemId = item.id
        }
    }

    // Deterministic version that targets a known item id (avoids timing issues)
    func requestRename(for id: UUID) {
        activeSourceId = "prompts"
        focus(id)
        pendingRenameItemId = id
        renameActiveItemId = id
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
        
        // Sync initial selection state for clipboard items
        if source is ClipboardSource {
            for item in History.shared.items where item.isSelected {
                selectedItemIds.insert(item.id)
            }
            if !selectedItemIds.isEmpty {
                markSelectedDirty()
            }
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
    
    // Get cached decorators for a source, creating/updating as needed
    func getDecorators(for sourceId: String) -> [UniversalItemDecorator] {
        let items = getItems(for: sourceId)
        
        // Initialize cache for this source if needed
        if _decoratorCache[sourceId] == nil {
            _decoratorCache[sourceId] = [:]
        }
        
        // Check if this source needs cache refresh
        if _decoratorCacheDirty.contains(sourceId) {
            // Update existing decorators with new data
            let sourceCache = _decoratorCache[sourceId]!
            var updatedCache: [UUID: UniversalItemDecorator] = [:]
            
            for item in items {
                if let existingDecorator = sourceCache[item.id] {
                    // Update existing decorator with new data
                    existingDecorator.updateBase(item)
                    updatedCache[item.id] = existingDecorator
                } else {
                    // Create new decorator for new items
                    updatedCache[item.id] = UniversalItemDecorator(item)
                }
            }
            
            _decoratorCache[sourceId] = updatedCache
            _decoratorCacheDirty.remove(sourceId)
        } else if _decoratorCache[sourceId]!.isEmpty && !items.isEmpty {
            // First time loading - create all decorators
            var sourceCache: [UUID: UniversalItemDecorator] = [:]
            for item in items {
                sourceCache[item.id] = UniversalItemDecorator(item)
            }
            _decoratorCache[sourceId] = sourceCache
        }
        
        // Return decorators in the same order as items
        return items.compactMap { _decoratorCache[sourceId]?[$0.id] }
    }
    
    // Mark a source's decorator cache as dirty (needs refresh)
    func markDecoratorsNeedRefresh(for sourceId: String) {
        _decoratorCacheDirty.insert(sourceId)
    }
    
    // Clear decorator cache for a source (when source is removed)
    func clearDecoratorCache(for sourceId: String) {
        _decoratorCache.removeValue(forKey: sourceId)
        _decoratorCacheDirty.remove(sourceId)
    }
    
    // Optimistically update a decorator's file info (for instant UI feedback)
    func optimisticallyUpdateItem(_ itemId: UUID, sourceId: String, newFileURL: URL, newTitle: String) {
        guard let decorator = _decoratorCache[sourceId]?[itemId] else { return }
        
        // Create updated ContentItem with new URL and title
        var updatedItem = decorator.base
        updatedItem = ContentItem(
            id: updatedItem.id,
            title: newTitle,
            timestamp: updatedItem.timestamp,
            sourceType: updatedItem.sourceType,
            sourceId: updatedItem.sourceId,
            fileURL: newFileURL,
            imageData: updatedItem.imageData,
            rtfData: updatedItem.rtfData,
            htmlData: updatedItem.htmlData,
            plainText: updatedItem.plainText,
            fileIdentity: updatedItem.fileIdentity,
            uniformTypeIdentifier: updatedItem.uniformTypeIdentifier,
            fileSize: updatedItem.fileSize,
            isFolder: updatedItem.isFolder,
            depth: updatedItem.depth,
            parentPath: updatedItem.parentPath,
            isSelected: updatedItem.isSelected,
            isVisible: updatedItem.isVisible
        )
        
        // Update the decorator immediately
        decorator.updateBase(updatedItem)
    }
    
    // Revert optimistic update by refreshing from source data
    func revertOptimisticUpdate(_ itemId: UUID, sourceId: String) {
        guard let decorator = _decoratorCache[sourceId]?[itemId],
              let source = sources[sourceId],
              let originalItem = source.items.first(where: { $0.id == itemId }) else { return }
        
        // Revert to original data from source
        decorator.updateBase(originalItem)
    }
    
    // Get cached decorators for selected context items (Aggregated shows only pasteable files)
    var selectedContextDecorators: [UniversalItemDecorator] {
        let displayItems = filteredForAggregatedDisplay(selectedContextItems)
        return displayItems.compactMap { item in
            // Ensure the source decorators are loaded first
            _ = getDecorators(for: item.sourceId)
            // Prefer cached decorator; fall back to ad-hoc for ephemeral items
            return _decoratorCache[item.sourceId]?[item.id] ?? UniversalItemDecorator(item)
        }
    }
    
    // Get cached decorators for selected example items (Aggregated shows only pasteable files)
    var selectedExampleDecorators: [UniversalItemDecorator] {
        let displayItems = filteredForAggregatedDisplay(selectedExampleItems)
        return displayItems.compactMap { item in
            // Ensure the source decorators are loaded first
            _ = getDecorators(for: item.sourceId)
            // Prefer cached decorator; fall back to ad-hoc for ephemeral items
            return _decoratorCache[item.sourceId]?[item.id] ?? UniversalItemDecorator(item)
        }
    }

    // In Aggregated tab, show only pasteable leaf items (no folder rows)
    private func filteredForAggregatedDisplay(_ items: [ContentItem]) -> [ContentItem] {
        guard activeSourceId == "aggregated" else { return items }
        // Drop folders; keep everything else (files, clipboard entries, images)
        return items.filter { !$0.isFolder }
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
    
    func stableUUID(for url: URL) -> UUID {
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
    
    // MARK: - Prompt Editor State Management
    
    func setPromptEditorText(_ text: String) {
        promptEditorText = text
    }
    
    func setPromptEditorEditing(_ editing: Bool) {
        isPromptEditorEditing = editing
        if !editing {
            // Reset text when exiting edit mode
            promptEditorText = ""
        }
    }
    
    func updatePromptEditorText(_ text: String) {
        promptEditorText = text
    }
}

// Global notifications for inline rename coordination
extension Notification.Name {
    static let CommitActiveRename = Notification.Name("ContentManager.CommitActiveRename")
    static let CancelActiveRename = Notification.Name("ContentManager.CancelActiveRename")
    static let promptEditorTextUpdated = Notification.Name("ContentManager.promptEditorTextUpdated")
}

// MARK: - Selected items caching helpers
extension ContentManager {
    func markSelectedDirty() {
        _selectedCacheDirty = true
        selectionVersion += 1  // Force UI update
    }
    
    private func makeSelectedItems() -> [ContentItem] {
        let items = allItems
        guard !selectedItemIds.isEmpty else { return [] }

        // For folder sources, we need to handle collapsed folders with selected children
        var hiddenSelectedItems: [ContentItem] = []
        // For selected folders, we also include all descendant files for paste/aggregated view
        var expandedFolderDescendants: [UUID: [ContentItem]] = [:] // folderId -> descendants

        // Check each source for selected items that might be hidden
        for sourceId in orderedSourceIds {
            guard let source = sources[sourceId] as? FileSystemSource else { continue }
            // Get all selected IDs that aren't visible in current items
            let visibleIds = Set(items.map { $0.id })
            let hiddenSelectedIds = selectedItemIds.subtracting(visibleIds)

            if !hiddenSelectedIds.isEmpty {
                // Scan the filesystem to find these hidden selected items (both files and folders)
                let foundItems = source.findItemsById(hiddenSelectedIds)
                hiddenSelectedItems.append(contentsOf: foundItems)
            }

            // For any selected folder (visible or hidden), gather all descendant files so they
            // participate in aggregated view and paste operations even when collapsed
            let allKnownItems = items + hiddenSelectedItems
            for fid in selectedItemIds {
                if expandedFolderDescendants[fid] != nil { continue }
                guard let folderItem = allKnownItems.first(where: { $0.id == fid && $0.isFolder }) else { continue }
                guard let baseURL = folderItem.fileURL else { continue }
                // Enumerate all descendant files
                let urls = enumerateDescendantFiles(at: baseURL)
                if urls.isEmpty { continue }
                var desc: [ContentItem] = []
                desc.reserveCapacity(urls.count)
                for url in urls {
                    do {
                        let vals = try url.resourceValues(forKeys: [.isDirectoryKey, .contentTypeKey, .contentModificationDateKey, .fileSizeKey])
                        if vals.isDirectory == true { continue }
                        let snap = FileIdentity.snapshot(for: url)
                        let type = FileSystemSource.resolvedType(for: url)
                        let cid = FileSystemSource.makeStableUUID(identity: snap.identity, fallbackPath: url.absoluteString)
                        // Compute depth relative to the base folder for nicer indentation in Aggregated tab
                        // In Aggregated view we don't show folders, so present files as flat items
                        let item = ContentItem(
                            id: cid,
                            title: url.lastPathComponent,
                            timestamp: vals.contentModificationDate ?? Date(),
                            sourceType: .folder,
                            sourceId: source.id,
                            fileURL: url,
                            imageData: nil,
                            rtfData: nil,
                            htmlData: nil,
                            plainText: nil,
                            fileIdentity: snap.identity,
                            uniformTypeIdentifier: type?.identifier,
                            fileSize: vals.fileSize.flatMap(Int64.init),
                            isFolder: false,
                            depth: 0,
                            parentPath: nil,
                            isSelected: true,
                            isVisible: true
                        )
                        desc.append(item)
                    } catch {
                        continue
                    }
                }
                if !desc.isEmpty { expandedFolderDescendants[fid] = desc }
            }
        }

        // Combine visible and hidden selected items
        let allItemsIncludingHidden = items + hiddenSelectedItems

        // Index folders by path for fast parent lookup
        var folderByPath: [String: ContentItem] = [:]
        folderByPath.reserveCapacity(allItemsIncludingHidden.count)
        for item in allItemsIncludingHidden where item.isFolder {
            if let path = item.fileURL?.path { folderByPath[path] = item }
        }
        
        // Determine which parent folders need to be included due to selected children
        var neededParentIds: Set<UUID> = []
        for item in allItemsIncludingHidden {
            guard selectedItemIds.contains(item.id) else { continue }
            if let parentPath = item.parentPath, let parent = folderByPath[parentPath] {
                if !selectedItemIds.contains(parent.id) {
                    neededParentIds.insert(parent.id)
                }
            }
        }
        
        // Build result with hierarchical grouping and expanded descendants for selected folders
        var result: [ContentItem] = []
        result.reserveCapacity(selectedItemIds.count + neededParentIds.count)
        var seen: Set<UUID> = []

        // Process items in hierarchical order: folders followed by their children
        for item in allItemsIncludingHidden {
            // Add folders (both needed parents and explicitly selected)
            if item.isFolder && (neededParentIds.contains(item.id) || selectedItemIds.contains(item.id)) {
                if !seen.contains(item.id) {
                    result.append(item)
                    seen.insert(item.id)

                    // Immediately add children of this folder that are selected
                    let folderPath = item.fileURL?.path
                    for childItem in allItemsIncludingHidden {
                        if selectedItemIds.contains(childItem.id) && 
                           !seen.contains(childItem.id) && 
                           childItem.parentPath == folderPath {
                            result.append(childItem)
                            seen.insert(childItem.id)
                        }
                    }

                    // If the folder itself is selected, also append all descendant files (collapsed case)
                    if selectedItemIds.contains(item.id), let desc = expandedFolderDescendants[item.id] {
                        for d in desc where !seen.contains(d.id) {
                            result.append(d)
                            seen.insert(d.id)
                        }
                    }
                }
            }
        }
        
        // Add any remaining selected items that don't have a parent (e.g., clipboard items)
        for item in allItemsIncludingHidden {
            if selectedItemIds.contains(item.id) && !seen.contains(item.id) {
                result.append(item)
                seen.insert(item.id)
            }
        }
        
        return result
    }
}
