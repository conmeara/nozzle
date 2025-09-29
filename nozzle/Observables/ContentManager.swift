import AppKit
import Foundation
import UniformTypeIdentifiers
import Observation
import OSLog

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

    private let signposter = OSSignposter(logger: Logger(subsystem: "org.conmeara.nozzle", category: "Perf.ContentManager"))
    
    // Phase 2: Centralized selection
    let selectionStore = SelectionStore()
    // Observable version counter to trigger UI updates when selection changes
    private(set) var selectionVersion: Int = 0

    private var selectedItemIds: Set<UUID> {
        Set(selectionStore.selected.map(\.itemId))
    }

    private func selectItemIfPresent(_ id: UUID, removeExample: Bool = true) {
        guard let content = item(for: id) else { return }
        selectionStore.insert(content.key)
        if removeExample {
            selectionStore.removeExample(content.key)
        }
    }

    private func key(for id: UUID) -> ContentKey? {
        guard let content = item(for: id) else { return nil }
        return content.key
    }
    
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

    // Manual deselection tracking for folder descendants
    @ObservationIgnored private var _folderSelectionExclusions: [UUID: DeselectionOverride] = [:]

    // Cache for hidden selections fetched off the main thread
    @ObservationIgnored private var _hiddenSelectedItems: [UUID: ContentItem] = [:]
    @ObservationIgnored private var _pendingHiddenFetch: Set<UUID> = []

    // Track in-flight descendant selection tasks per folder to avoid stale updates
    @ObservationIgnored private var _descendantSelectionTokens: [UUID: UUID] = [:]

    private struct DeselectionOverride: Sendable {
        let path: String
        let appliesToDescendants: Bool
    }

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
        let orderedKeys = selectionStore.orderedSelection
        guard !orderedKeys.isEmpty else { return [] }
        let map = Dictionary(uniqueKeysWithValues: selectedItems.map { ($0.key, $0) })
        return orderedKeys.compactMap { key in
            guard let item = map[key], !selectionStore.isExample(key) else { return nil }
            return item
        }
    }
    
    var selectedExampleItems: [ContentItem] {
        let orderedKeys = selectionStore.orderedSelection
        guard !orderedKeys.isEmpty else { return [] }
        let map = Dictionary(uniqueKeysWithValues: selectedItems.map { ($0.key, $0) })
        return orderedKeys.compactMap { key in
            guard let item = map[key], selectionStore.isExample(key) else { return nil }
            return item
        }
    }
    
    // Count of selected files only (excludes folders for badge display)
    var selectedFileCount: Int {
        selectedItems.filter { !$0.isFolder }.count
    }
    
    var focusedContentItem: ContentItem? {
        item(for: focusedItemId)
    }
    
    var allItems: [ContentItem] {
        orderedSourceIds.flatMap { sources[$0]?.items ?? [] }
    }
    
    // Computed views
    var activeItems: [ContentItem] {
        guard let src = sources[activeSourceId] else { return [] }
        return src.items
    }

    func markItemsDirty() {
        _hiddenSelectedItems = _hiddenSelectedItems.filter { selectedItemIds.contains($0.key) }
        _pendingHiddenFetch.formIntersection(selectedItemIds)
        resyncDeselectionOverridesWithCurrentPaths()
    }

    func clearHiddenSelections(for sourceId: String, underPath prefixPath: String? = nil) {
        guard !_hiddenSelectedItems.isEmpty else { return }

        let normalizedPrefix: String? = {
            guard let prefixPath else { return nil }
            if prefixPath.hasSuffix("/") { return prefixPath }
            return prefixPath + "/"
        }()

        var keysToRemove: [UUID] = []

        for (id, item) in _hiddenSelectedItems where item.sourceId == sourceId {
            let shouldRemove: Bool

            if let prefixPath {
                guard let itemPath = item.fileURL?.path else { continue }
                if itemPath == prefixPath {
                    shouldRemove = true
                } else if let normalizedPrefix {
                    shouldRemove = itemPath.hasPrefix(normalizedPrefix)
                } else {
                    shouldRemove = false
                }
            } else {
                shouldRemove = true
            }

            if shouldRemove {
                keysToRemove.append(id)
            }
        }

        guard !keysToRemove.isEmpty else { return }

        var needsPrefetch: Set<UUID> = []
        for id in keysToRemove {
            if isSelected(id) {
                _pendingHiddenFetch.insert(id)
                needsPrefetch.insert(id)
            } else {
                _hiddenSelectedItems.removeValue(forKey: id)
                _pendingHiddenFetch.remove(id)
            }
        }
        if !needsPrefetch.isEmpty {
            scheduleHiddenSelectionPrefetch(for: needsPrefetch, force: true)
        }

        markSelectedDirty()
    }

    func item(for id: UUID?) -> ContentItem? {
        guard let id else { return nil }
        if let hidden = _hiddenSelectedItems[id] {
            return hidden
        }

        for sourceId in orderedSourceIds {
            guard let source = sources[sourceId] else { continue }
            if let hierarchical = source as? HierarchicalContentSource,
               let resolved = hierarchical.item(with: id) {
                return resolved
            }
            if let match = source.items.first(where: { $0.id == id }) {
                return match
            }
        }

        return nil
    }

    func item(for key: ContentKey) -> ContentItem? {
        if let hidden = _hiddenSelectedItems[key.itemId], hidden.sourceId == key.sourceId {
            return hidden
        }

        guard let source = sources[key.sourceId] else { return nil }

        if let hierarchical = source as? HierarchicalContentSource,
           let resolved = hierarchical.item(with: key.itemId) {
            return resolved
        }

        if let match = source.items.first(where: { $0.id == key.itemId }) {
            return match
        }

        return nil
    }
    
    // Selection management
    func toggleSelection(_ id: UUID) {
        // Check if this is a folder and handle specially
        if let folderItem = item(for: id), folderItem.isFolder {
            toggleFolderSelection(id)
        } else {
            // Regular item selection
            guard let toggledItem = item(for: id) else { return }
            let key = toggledItem.key
            let wasSelected = selectionStore.contains(key)
            if wasSelected {
                selectionStore.remove(key)
            } else {
                selectionStore.insert(key)
            }
            updateFolderDeselectionOverride(for: toggledItem, deselected: wasSelected)
            // Bridge to clipboard selection if needed
            syncClipboardSelection(id)
        }
        markSelectedDirty()
    }
    
    private func toggleFolderSelection(_ folderId: UUID) {
        guard let folderItem = item(for: folderId),
              folderItem.isFolder,
              sources[folderItem.sourceId] is HierarchicalContentSource else { return }

        let children = visibleChildItems(of: folderItem)
        let currentState = getFolderSelectionState(folderId)
        
        switch currentState {
        case .none:
            // No children selected - select everything
            removeDeselectionOverrides(inSubtreeOf: folderItem)
            selectionStore.insert(folderItem.key)
            selectionStore.removeExample(folderItem.key)
            updateFolderDeselectionOverride(for: folderItem, deselected: false)
            if children.isEmpty {
                // Collapsed folder - enumerate and select all descendant files via source
                selectAllDescendantItems(for: folderItem, sourceId: folderItem.sourceId)
            } else {
                // Expanded folder - select all visible children
                selectFolderChildren(folderId)
            }
            
        case .partial, .all:
            // Some or all children selected - deselect everything
            selectionStore.remove(folderItem.key)
            updateFolderDeselectionOverride(for: folderItem, deselected: true)
            if children.isEmpty {
                // Collapsed folder - enumerate and deselect all descendant files via source
                deselectAllDescendantItems(for: folderItem, sourceId: folderItem.sourceId)
            } else {
                // Expanded folder - deselect all visible children
                deselectFolderChildren(folderId)
            }
        }
        markSelectedDirty()
    }
    
    func selectFolderChildren(_ folderId: UUID) {
        guard let folderItem = item(for: folderId),
              folderItem.isFolder,
              sources[folderItem.sourceId] is HierarchicalContentSource else { return }
        
        let children = visibleChildItems(of: folderItem)

        selectionStore.insert(folderItem.key)
        selectionStore.removeExample(folderItem.key)
        updateFolderDeselectionOverride(for: folderItem, deselected: false)

        if children.isEmpty {
            selectAllDescendantItems(for: folderItem, sourceId: folderItem.sourceId)
            return
        }

        for item in children {
            guard !isUnderDeselectionOverride(item) else { continue }
            if item.isFolder {
                selectFolderChildren(item.id)
            } else {
                selectionStore.insert(item.key)
                selectionStore.removeExample(item.key)
                updateFolderDeselectionOverride(for: item, deselected: false)
            }
        }
        markSelectedDirty()
    }
    
    func deselectFolderChildren(_ folderId: UUID) {
        guard let folderItem = item(for: folderId),
              folderItem.isFolder,
              sources[folderItem.sourceId] is HierarchicalContentSource else { return }

        let children = visibleChildItems(of: folderItem)

        selectionStore.remove(folderItem.key)
        updateFolderDeselectionOverride(for: folderItem, deselected: true)

        if children.isEmpty {
            deselectAllDescendantItems(for: folderItem, sourceId: folderItem.sourceId)
            return
        }

        // Deselect all children of this folder (but not the folder itself)
        for item in children {
            if item.isFolder {
                deselectFolderChildren(item.id)
            } else {
                selectionStore.remove(item.key)
                updateFolderDeselectionOverride(for: item, deselected: true)
            }
        }
        markSelectedDirty()
    }

    private func updateFolderDeselectionOverride(for item: ContentItem, deselected: Bool) {
        guard item.sourceType == .folder else {
            _folderSelectionExclusions.removeValue(forKey: item.id)
            return
        }
        guard let normalized = normalizedPath(for: item) else {
            _folderSelectionExclusions.removeValue(forKey: item.id)
            return
        }

        if deselected {
            if hasSelectedFolderAncestor(for: item) {
                _folderSelectionExclusions[item.id] = DeselectionOverride(
                    path: normalized,
                    appliesToDescendants: item.isFolder
                )
            } else {
                _folderSelectionExclusions.removeValue(forKey: item.id)
            }
        } else {
            _folderSelectionExclusions.removeValue(forKey: item.id)
        }
    }

    private func removeDeselectionOverrides(inSubtreeOf folder: ContentItem) {
        guard folder.sourceType == .folder,
              let basePath = normalizedPath(for: folder),
              !_folderSelectionExclusions.isEmpty else { return }

        var toRemove: [UUID] = []
        for (id, override) in _folderSelectionExclusions where override.path.hasPrefix(basePath) {
            toRemove.append(id)
        }

        for id in toRemove {
            _folderSelectionExclusions.removeValue(forKey: id)
        }
    }

    private func isUnderDeselectionOverride(_ item: ContentItem) -> Bool {
        guard item.sourceType == .folder,
              let path = normalizedPath(for: item) else { return false }
        if _folderSelectionExclusions[item.id] != nil { return true }
        return hasDeselectionOverride(forPath: path, excluding: item.id)
    }

    private func resyncDeselectionOverridesWithCurrentPaths() {
        guard !_folderSelectionExclusions.isEmpty else { return }

        var updated: [UUID: DeselectionOverride] = [:]
        updated.reserveCapacity(_folderSelectionExclusions.count)
        var changed = false

        for (id, override) in _folderSelectionExclusions {
            guard let item = item(for: id) else {
                changed = true
                continue
            }

            guard let newPath = normalizedPath(for: item) else {
                changed = true
                continue
            }

            if newPath != override.path {
                updated[id] = DeselectionOverride(path: newPath, appliesToDescendants: override.appliesToDescendants)
                changed = true
            } else {
                updated[id] = override
            }
        }

        if changed {
            _folderSelectionExclusions = updated
        }
    }

    private func hasDeselectionOverride(forPath path: String, excluding id: UUID? = nil) -> Bool {
        guard !_folderSelectionExclusions.isEmpty else { return false }
        for (key, override) in _folderSelectionExclusions {
            if let id, key == id { continue }
            if override.appliesToDescendants {
                if path.hasPrefix(override.path) { return true }
            } else if path == override.path {
                return true
            }
        }
        return false
    }

    private func hasDeselectionOverrideUnder(prefixOf folder: ContentItem) -> Bool {
        guard let base = normalizedPath(for: folder) else { return false }
        for (_, override) in _folderSelectionExclusions where override.path.hasPrefix(base) {
            return true
        }
        return false
    }

    private func hasSelectedFolderAncestor(for item: ContentItem) -> Bool {
        guard item.sourceType == .folder,
              let itemPath = normalizedPath(for: item) else { return false }
        for key in selectionStore.selected where key.itemId != item.id {
            guard let ancestor = self.item(for: key),
                  ancestor.isFolder,
                  ancestor.sourceType == .folder,
                  let ancestorPath = normalizedPath(for: ancestor) else { continue }
            if itemPath.hasPrefix(ancestorPath) {
                return true
            }
        }
        return false
    }

    private func normalizedPath(for item: ContentItem) -> String? {
        guard let path = item.fileURL?.path else { return nil }
        return item.isFolder ? normalizedFolderPath(path) : path
    }

    nonisolated private static func normalizedFolderPath(_ path: String) -> String {
        path.hasSuffix("/") ? path : path + "/"
    }

    private func normalizedFolderPath(_ path: String) -> String {
        Self.normalizedFolderPath(path)
    }
    
    // Helper functions for collapsed folder selection
    private func selectAllDescendantItems(for folder: ContentItem, sourceId: String) {
        let folderId = folder.id
        let token = registerDescendantSelectionTask(for: folderId)
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let context = await self.backgroundSelectionInputs(for: folderId, sourceId: sourceId)
            let snapshot: HierarchyDescendantSnapshot
            if let folderPath = context.folderPath,
               context.supportsBackgroundEnumeration {
                snapshot = ContentManager.makeDescendantSnapshot(atPath: folderPath)
            } else {
                snapshot = await self.snapshotOnMain(for: folderId, sourceId: sourceId)
            }
            let snapshotIds = snapshot.isEmpty ? Set<UUID>() : Set(snapshot.items.filter { !$0.isFolder }.map(\.id))
            if !snapshotIds.isEmpty {
                await self.markHiddenFetchPending(for: snapshotIds)
            }
            let resolvedItems: [ContentItem]
            if snapshot.isEmpty {
                resolvedItems = []
            } else {
                let ids = Set(snapshot.itemIds)
                resolvedItems = await self.resolveItemsOnMain(for: ids, sourceId: sourceId)
            }
            await self.applyDescendantSelection(
                snapshot: snapshot,
                resolvedItems: resolvedItems,
                selecting: true,
                folderId: folderId,
                sourceId: sourceId,
                token: token
            )
        }
    }

    private func deselectAllDescendantItems(for folder: ContentItem, sourceId: String) {
        let folderId = folder.id
        let token = registerDescendantSelectionTask(for: folderId)
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let context = await self.backgroundSelectionInputs(for: folderId, sourceId: sourceId)
            let snapshot: HierarchyDescendantSnapshot
            if let folderPath = context.folderPath,
               context.supportsBackgroundEnumeration {
                snapshot = ContentManager.makeDescendantSnapshot(atPath: folderPath)
            } else {
                snapshot = await self.snapshotOnMain(for: folderId, sourceId: sourceId)
            }
            let snapshotIds = snapshot.isEmpty ? Set<UUID>() : Set(snapshot.items.filter { !$0.isFolder }.map(\.id))
            if !snapshotIds.isEmpty {
                await self.markHiddenFetchPending(for: snapshotIds)
            }
            let resolvedItems: [ContentItem]
            if snapshot.isEmpty {
                resolvedItems = []
            } else {
                let ids = Set(snapshot.itemIds)
                resolvedItems = await self.resolveItemsOnMain(for: ids, sourceId: sourceId)
            }
            await self.applyDescendantSelection(
                snapshot: snapshot,
                resolvedItems: resolvedItems,
                selecting: false,
                folderId: folderId,
                sourceId: sourceId,
                token: token
            )
        }
    }

    private func registerDescendantSelectionTask(for folderId: UUID) -> UUID {
        let token = UUID()
        _descendantSelectionTokens[folderId] = token
        return token
    }

    private struct BackgroundSelectionContext: Sendable {
        let folderPath: String?
        let supportsBackgroundEnumeration: Bool
    }

    @MainActor
    private func backgroundSelectionInputs(for folderId: UUID, sourceId: String) -> BackgroundSelectionContext {
        guard let source = sources[sourceId] else {
            return BackgroundSelectionContext(folderPath: nil, supportsBackgroundEnumeration: false)
        }

        let item = source.items.first(where: { $0.id == folderId })
        let folderPath = item?.fileURL?.path
        let supportsBackground = source.type == .folder && folderPath != nil

        return BackgroundSelectionContext(
            folderPath: folderPath,
            supportsBackgroundEnumeration: supportsBackground
        )
    }

    @MainActor
    private func snapshotOnMain(for folderId: UUID, sourceId: String) -> HierarchyDescendantSnapshot {
        guard let source = sources[sourceId] as? HierarchicalContentSource else {
            return HierarchyDescendantSnapshot(items: [])
        }
        return source.descendantSnapshot(for: folderId)
    }

    @MainActor
    private func markHiddenFetchPending(for ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        _pendingHiddenFetch.formUnion(ids)
    }

    nonisolated private static func makeDescendantSnapshot(atPath path: String) -> HierarchyDescendantSnapshot {
        let baseURL = URL(fileURLWithPath: path)
        var descendants: [HierarchyDescendantItem] = []
        let fm = FileManager.default

        if let enumerator = fm.enumerator(
            at: baseURL,
            includingPropertiesForKeys: [.isDirectoryKey, .contentTypeKey, .fileResourceIdentifierKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let url as URL in enumerator {
                guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentTypeKey, .fileResourceIdentifierKey]) else {
                    continue
                }

                let type = values.contentType ?? FileSystemSource.resolvedType(for: url)
                let identity = values.fileResourceIdentifier as? Data
                let id = FileSystemSource.makeStableUUID(identity: identity, fallbackPath: url.absoluteString)
                let isDirectory = values.isDirectory == true
                let normalizedPath = isDirectory ? normalizedFolderPath(url.path) : url.path

                descendants.append(
                    HierarchyDescendantItem(
                        id: id,
                        path: normalizedPath,
                        isText: isTextType(type),
                        isFolder: isDirectory
                    )
                )
            }
        }

        return HierarchyDescendantSnapshot(items: descendants)
    }

    @MainActor
    private func resolveItemsOnMain(for ids: Set<UUID>, sourceId: String) async -> [ContentItem] {
        guard let source = sources[sourceId] as? HierarchicalContentSource else { return [] }
        return await source.resolveItems(for: ids)
    }

    @MainActor
    private func applyDescendantSelection(
        snapshot: HierarchyDescendantSnapshot,
        resolvedItems: [ContentItem],
        selecting: Bool,
        folderId: UUID,
        sourceId: String,
        token: UUID
    ) {
        let interval = signposter.beginInterval("applyDescendantSelection")
        defer { signposter.endInterval("applyDescendantSelection", interval) }

        guard _descendantSelectionTokens[folderId] == token else { return }
        _descendantSelectionTokens.removeValue(forKey: folderId)

        guard !snapshot.isEmpty else { return }

        let folderKey = ContentKey(sourceId: sourceId, itemId: folderId)

        if selecting {
            guard selectionStore.contains(folderKey) else { return }
        } else {
            guard !selectionStore.contains(folderKey) else { return }
        }

        let resolvedById = Dictionary(uniqueKeysWithValues: resolvedItems.map { ($0.id, $0) })

        let processed: [HierarchyDescendantItem]
        if selecting {
            processed = snapshot.items.filter { item in
                let path = item.isFolder ? Self.normalizedFolderPath(item.path) : item.path
                return !hasDeselectionOverride(forPath: path)
            }
        } else {
            processed = snapshot.items
        }

        if selecting {
            for item in processed {
                let key = ContentKey(sourceId: sourceId, itemId: item.id)
                if item.isFolder {
                    selectionStore.remove(key)
                    _folderSelectionExclusions.removeValue(forKey: item.id)
                    continue
                }

                selectionStore.insert(key)
                selectionStore.removeExample(key)
                _folderSelectionExclusions.removeValue(forKey: item.id)
                if let resolved = resolvedById[item.id] {
                    _hiddenSelectedItems[item.id] = resolved
                }
            }
            let fileIDs = processed.filter { !$0.isFolder }.map(\.id)
            if !fileIDs.isEmpty {
                _pendingHiddenFetch.subtract(Set(fileIDs))
            }
        } else {
            for item in processed {
                let key = ContentKey(sourceId: sourceId, itemId: item.id)
                selectionStore.remove(key)

                if item.isFolder {
                    _folderSelectionExclusions.removeValue(forKey: item.id)
                    continue
                }

                _hiddenSelectedItems.removeValue(forKey: item.id)
                _pendingHiddenFetch.remove(item.id)
            }
        }
        markSelectedDirty()
    }

    func clearSelection() {
        selectionStore.clearAll()
        // Also clear clipboard selection (boolean test only)
        if sources["clipboard"] is ClipboardSource {
            History.shared.items.forEach { $0.isSelected = false }
        }
        _hiddenSelectedItems.removeAll()
        _pendingHiddenFetch.removeAll()
        _folderSelectionExclusions.removeAll()
        markSelectedDirty()
    }
    
    func isSelected(_ id: UUID) -> Bool {
        _ = selectionVersion  // Establish dependency for SwiftUI observation
        if let item = item(for: id) {
            return selectionStore.contains(item.key)
        }
        return selectionStore.contains(itemId: id)
    }

    // Treat an item as selected if:
    // - It is explicitly selected, or
    // - It is a file inside any selected folder (use path prefix check)
    func isSelected(effectively item: ContentItem) -> Bool {
        if selectionStore.contains(item.key) { return true }
        if _folderSelectionExclusions[item.id] != nil { return false }
        guard item.sourceType == .folder,
              let rawPath = item.fileURL?.path else { return false }
        let normalizedPath = item.isFolder ? normalizedFolderPath(rawPath) : rawPath
        if hasDeselectionOverride(forPath: normalizedPath, excluding: item.id) { return false }
        // Any selected folder that is an ancestor of this item implies effective selection
        for key in selectionStore.selected {
            guard let folder = self.item(for: key),
                  folder.isFolder,
                  let folderRawPath = folder.fileURL?.path else { continue }
                let folderPath = normalizedFolderPath(folderRawPath)
            if folder.id != item.id, normalizedPath.hasPrefix(folderPath) {
                return true
            }
        }
        return false
    }
    
    func getFolderSelectionState(_ folderId: UUID) -> FolderSelectionState {
        _ = selectionVersion  // Establish dependency for SwiftUI observation
        guard let folderItem = item(for: folderId),
              folderItem.isFolder,
              let source = sources[folderItem.sourceId] else { return .none }

        let children = visibleChildItems(of: folderItem)

        // If folder is collapsed (no visible children), compute state from real descendants on disk
        if children.isEmpty {
            guard let hierarchical = source as? HierarchicalContentSource else {
                return .none
            }

            let snapshot = hierarchical.descendantSnapshot(for: folderId)
            let fileIds = snapshot.items.filter { !$0.isFolder }.map(\.id)

            guard !fileIds.isEmpty else {
                return selectionStore.contains(folderItem.key) ? .all : .none
            }

            if selectionStore.contains(folderItem.key),
               !hasDeselectionOverrideUnder(prefixOf: folderItem) {
                return .all
            }

            let explicit = fileIds.reduce(into: 0) { count, id in
                if isSelected(id) { count += 1 }
            }

            if explicit == 0 {
                if selectionStore.contains(folderItem.key) {
                    return hasDeselectionOverrideUnder(prefixOf: folderItem) ? .partial : .all
                }
                return .none
            }

            return (explicit == fileIds.count) ? .all : .partial
        }
        
        // For expanded folders, calculate based on per-child state so mixed selections stay accurate
        let fileChildren = children.filter { !$0.isFolder }
        let subfolders = children.filter { $0.isFolder }

        var anySelection = false
        var allFullySelected = true

        // Files are fully selected only when their UUID is tracked in the selection set
        for file in fileChildren {
            if isSelected(effectively: file) {
                anySelection = true
            } else {
                allFullySelected = false
            }
        }

        // Subfolders inherit their own state; aggregate precisely instead of collapsing to a single flag
        for subfolder in subfolders {
            switch getFolderSelectionState(subfolder.id) {
            case .all:
                anySelection = true
            case .partial:
                anySelection = true
                allFullySelected = false
            case .none:
                allFullySelected = false
            }
        }

        guard anySelection else { return .none }
        return allFullySelected ? .all : .partial
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
        if selectionStore.contains(folderItem.key) {
            selectFolderChildren(folderItem.id)
        }
        markSelectedDirty()
    }

    private func syncClipboardSelection(_ id: UUID) {
        // If this is a clipboard item, sync with History
        if let item = item(for: id),
           item.sourceType == .clipboard {
            if let historyItem = History.shared.items.first(where: { $0.id == id }) {
                historyItem.isSelected = selectionStore.contains(item.key)
            }
        }
    }
    
    // Registration
    func registerSource<T: ContentSource>(_ source: T) {
        sources[source.id] = source
        if !orderedSourceIds.contains(source.id) {
            orderedSourceIds.append(source.id)
        }

        markItemsDirty()

        // Sync initial selection state for clipboard items
        if source is ClipboardSource {
            for item in History.shared.items where item.isSelected {
                selectItemIfPresent(item.id)
            }
            if !selectionStore.isEmpty {
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
        markItemsDirty()
        
        // Clear any selections from this source
        let sourceItems = source.items
        selectionStore.removeAll(forSourceId: sourceId)
        if !_hiddenSelectedItems.isEmpty {
            let idsToDrop = _hiddenSelectedItems.compactMap { entry -> UUID? in
                entry.value.sourceId == sourceId ? entry.key : nil
            }
            for id in idsToDrop {
                _hiddenSelectedItems.removeValue(forKey: id)
                _pendingHiddenFetch.remove(id)
            }
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

        // Clear hidden caches tied to this source
        clearHiddenSelections(for: sourceId)

        markSelectedDirty()

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
        return items.filter { $0.capabilities.contains(.pasteable) }
    }
    
    // Search
    func searchAcrossAllSources(query: String) -> [ContentItem] {
        sources.values.flatMap { $0.search(query: query) }
    }
    
    // MARK: - Example state
    func isExample(_ id: UUID) -> Bool {
        _ = selectionVersion  // Establish dependency for SwiftUI observation
        guard let key = key(for: id) else { return false }
        return selectionStore.isExample(key)
    }

    func toggleExample(_ id: UUID) {
        // Allow toggling example state for any textual items (no need to be selected as context)
        guard isTextualItem(id) else { return }
        guard let item = item(for: id) else { return }
        let key = item.key

        if selectionStore.isExample(key) {
            // Turning OFF example: clear on folder and its descendants
            selectionStore.removeExample(key)
            if item.isFolder {
                let childIDs = descendantTextItemIDs(for: item)
                for cid in childIDs {
                    let childKey = ContentKey(sourceId: item.sourceId, itemId: cid)
                    selectionStore.removeExample(childKey)
                    _hiddenSelectedItems.removeValue(forKey: cid)
                    _pendingHiddenFetch.remove(cid)
                }
            }
        } else {
            // Turning ON example
            selectionStore.addExample(key)
            if item.isFolder {
                // Select and mark all textual descendants as examples (even if collapsed)
                let childIDs = descendantTextItemIDs(for: item)
                if !childIDs.isEmpty {
                    let keys = childIDs.map { ContentKey(sourceId: item.sourceId, itemId: $0) }
                    selectionStore.insertManyPreservingOrder(keys)
                    for childKey in keys {
                        selectionStore.addExample(childKey)
                    }
                    scheduleHiddenSelectionPrefetch(for: Set(childIDs))
                }
            }
        }
        markSelectedDirty()
    }
    
    // Collect all textual descendant file UUIDs for a folder item by scanning the filesystem
    private func descendantTextItemIDs(for folder: ContentItem) -> [UUID] {
        guard folder.isFolder,
              let source = sources[folder.sourceId] as? HierarchicalContentSource else { return [] }
        return source.descendantSnapshot(for: folder.id).textItemIds
    }

    private func visibleChildItems(of folder: ContentItem) -> [ContentItem] {
        if let hierarchical = sources[folder.sourceId] as? HierarchicalContentSource {
            return hierarchical.visibleChildren(of: folder.id)
        }

        guard let sourceItems = sources[folder.sourceId]?.items,
              let startIndex = sourceItems.firstIndex(where: { $0.id == folder.id }) else { return [] }

        let childDepth = folder.depth + 1
        var results: [ContentItem] = []
        var index = startIndex + 1

        while index < sourceItems.count {
            let item = sourceItems[index]
            if item.depth <= folder.depth { break }
            if item.depth == childDepth {
                results.append(item)
            }
            index += 1
        }
        return results
    }
    func canToggleExample(_ id: UUID) -> Bool {
        guard let item = item(for: id), selectionStore.contains(item.key) else { return false }
        return isTextualItem(id)
    }
    
    func isTextualItem(_ id: UUID) -> Bool {
        guard let item = item(for: id) else { return false }
        
        if item.isFolder {
            // Allow folder examples only if all descendant files are textual and there is at least one file
            guard let source = sources[item.sourceId] as? HierarchicalContentSource else { return false }
            let snapshot = source.descendantSnapshot(for: item.id)
            guard !snapshot.isEmpty else { return false }
            return snapshot.items.allSatisfy { $0.isText }
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
        guard !selectionStore.isEmpty else { return [] }

        // For folder sources, we need to handle collapsed folders with selected children
        var hiddenSelectedItems: [ContentItem] = []

        let visibleIds = Set(items.map { $0.id })
        let hiddenSelectedIds = selectedItemIds.subtracting(visibleIds)

        if !hiddenSelectedIds.isEmpty {
            let cachedHidden = hiddenSelectedIds.compactMap { _hiddenSelectedItems[$0] }
            if !cachedHidden.isEmpty {
                hiddenSelectedItems.append(contentsOf: cachedHidden.filter { !$0.isFolder })
            }

            let cachedIds = Set(cachedHidden.map { $0.id })
            let missingHidden = hiddenSelectedIds.subtracting(cachedIds)
            if !missingHidden.isEmpty {
                scheduleHiddenSelectionPrefetch(for: missingHidden)
            }
        }

        // Combine visible and hidden selected items
        let allItemsIncludingHidden = items + hiddenSelectedItems

        // Index folders and children once to avoid repeated scans when building the result
        var folderByPath: [String: ContentItem] = [:]
        var childrenByParent: [String: [ContentItem]] = [:]
        folderByPath.reserveCapacity(allItemsIncludingHidden.count)

        for item in allItemsIncludingHidden {
            if item.isFolder, let path = item.fileURL?.path {
                folderByPath[path] = item
            }
            if let parentPath = item.parentPath {
                childrenByParent[parentPath, default: []].append(item)
            }
        }

        // Determine which parent folders need to be included for display due to selected children
        var neededParentIds: Set<UUID> = []
        for item in allItemsIncludingHidden where selectionStore.contains(item.key) {
            if let parentPath = item.parentPath,
               let parent = folderByPath[parentPath] {
                neededParentIds.insert(parent.id)
            }
        }

        // Build result with hierarchical grouping: parent folders followed by their selected children
        var result: [ContentItem] = []
        result.reserveCapacity(selectionStore.selected.count + neededParentIds.count)
        var seen: Set<UUID> = []

        for item in allItemsIncludingHidden {
            if item.isFolder,
               neededParentIds.contains(item.id),
               !seen.contains(item.id) {
                result.append(item)
                seen.insert(item.id)

                if let folderPath = item.fileURL?.path,
                   let children = childrenByParent[folderPath] {
                    for child in children where selectionStore.contains(child.key) && !seen.contains(child.id) {
                        result.append(child)
                        seen.insert(child.id)
                    }
                }
                continue
            }

            if selectionStore.contains(item.key) && !seen.contains(item.id) {
                result.append(item)
                seen.insert(item.id)
            }
        }

        return result
    }
}

extension ContentManager {
    private func scheduleHiddenSelectionPrefetch(for ids: Set<UUID>, force: Bool = false) {
        let newRequests: Set<UUID> = force ? ids : ids.subtracting(_pendingHiddenFetch)
        guard !newRequests.isEmpty else { return }

        _pendingHiddenFetch.formUnion(newRequests)

        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }

            var remaining = newRequests
            let sourceIds: [String] = await MainActor.run {
                self.sources.compactMap { key, value in
                    (value is HierarchicalContentSource) ? key : nil
                }
            }

            for sourceId in sourceIds {
                guard !remaining.isEmpty else { break }
                let found = await self.resolveItemsOnMain(for: remaining, sourceId: sourceId)
                guard !found.isEmpty else { continue }

                let foundIds = Set(found.map { $0.id })
                remaining.subtract(foundIds)

                await MainActor.run { [weak self] in
                    guard let self else { return }
                    for item in found {
                        self._hiddenSelectedItems[item.id] = item
                    }
                    self._pendingHiddenFetch.subtract(foundIds)

                    // Only trigger a refresh if any of the resolved IDs are still selected
                    if !foundIds.isDisjoint(with: self.selectedItemIds) {
                        self.markSelectedDirty()
                    }
                }
            }

            if !remaining.isEmpty {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self._pendingHiddenFetch.subtract(remaining)
                }
            }
        }
    }
}

private extension ContentManager {
    nonisolated static func isTextType(_ type: UTType?) -> Bool {
        guard let type else { return false }
        if type.conforms(to: .text) { return true }
        if type == .rtf || type == .rtfd || type == .html { return true }
        if type.identifier == "net.daringfireball.markdown" ||
            type.identifier == "public.markdown" ||
            type.preferredFilenameExtension == "md" {
            return true
        }
        return false
    }
}

#if DEBUG
extension ContentManager {
    func resetForTesting() {
        sources.values.forEach { $0.stopMonitoring() }
        sources.removeAll()
        orderedSourceIds.removeAll()
        activeSourceId = "clipboard"
        lastNonPromptsSourceId = "clipboard"

        selectionStore.clearAll()
        selectionVersion = 0
        focusedItemId = nil
        renameActiveItemId = nil
        pendingRenameItemId = nil
        promptEditorText = ""
        isPromptEditorEditing = false
        enhanceButtonClicked = false

        _selectedCache.removeAll()
        _selectedCacheDirty = true
        _decoratorCache.removeAll()
        _decoratorCacheDirty.removeAll()
        _hiddenSelectedItems.removeAll()
        _pendingHiddenFetch.removeAll()
        _folderSelectionExclusions.removeAll()
        _descendantSelectionTokens.removeAll()
    }
}
#endif
