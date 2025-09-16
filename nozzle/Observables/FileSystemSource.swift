import AppKit
import UniformTypeIdentifiers
import Observation
import CoreServices
import OSLog
import Defaults

// MARK: - Sorting Enums

enum FileSortOrder: String, CaseIterable {
    case name = "name"
    case dateModified = "dateModified"
    case size = "size"
    case type = "type"
}

enum FileSortDirection: String, CaseIterable {
    case ascending = "ascending"
    case descending = "descending"
}

@Observable @MainActor
final class FileSystemSource: ContentSource, HierarchicalContentSource {
    private static let refreshLogger = Logger(subsystem: "org.conmeara.nozzle.content", category: "FileSystemSource")
    private static let directoryResourceKeys: Set<URLResourceKey> = [
        .isDirectoryKey,
        .contentModificationDateKey,
        .fileSizeKey,
        .fileResourceIdentifierKey,
        .contentTypeKey
    ]

    nonisolated let id: String  // Need nonisolated access for event persistence
    let name: String
    let icon: NSImage
    let type: ContentSourceType = .folder
    nonisolated let folderURL: URL  // Expose for bookmark cleanup and settings
    private var cachedItems: [ContentItem] = []
    private var lastRefreshTime: Date = .distantPast
    private let refreshInterval: TimeInterval = 30.0 // Don't refresh if data is less than 30 seconds old
    private var directoryModDateCache: [String: Date] = [:] // Cache directory modification dates
    
    // Folder expansion state
    private var expansionState: FolderExpansionState
    
    var isMonitoring: Bool = false
    var searchQuery: String = ""
    
    // Sorting configuration
    var sortOrder: FileSortOrder = .name
    var sortDirection: FileSortDirection = .ascending
    
    // FSEvents monitoring
    private var stream: FSEventsStream?
    private let queue = DispatchQueue(label: "org.conmeara.nozzle.fs.\(UUID().uuidString)")
    private var eventCoalescer: Throttler
    
    // Thread-safe pending paths storage
    private let pendingPathsLock = NSLock()
    private var _pendingPaths: Set<String> = []
    
    private var pendingPaths: Set<String> {
        get {
            pendingPathsLock.lock()
            defer { pendingPathsLock.unlock() }
            return _pendingPaths
        }
        set {
            pendingPathsLock.lock()
            defer { pendingPathsLock.unlock() }
            _pendingPaths = newValue
        }
    }
    
    // Fast lookup for rename/move resolution
    private var indexByIdentity: [Data: Int] = [:]
    private var indexByPath: [String: Int] = [:]
    private var indexById: [UUID: Int] = [:]
    
    // Resort suspension for stable editing
    private var suspendResortItemId: UUID?

    private struct DirectoryEntry {
        let url: URL
        let snapshot: FileIdentity.Snapshot
        let typeIdentifier: String?
    }

    private struct DescendantSnapshotCacheEntry {
        let items: [HierarchyDescendantItem]
        let modificationDate: Date
    }

    private final class DescendantCacheStore: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [String: DescendantSnapshotCacheEntry] = [:]

        func entry(for path: String) -> DescendantSnapshotCacheEntry? {
            lock.lock()
            defer { lock.unlock() }
            return storage[path]
        }

        func store(_ entry: DescendantSnapshotCacheEntry, for path: String) {
            lock.lock()
            storage[path] = entry
            lock.unlock()
        }

        func removeAll() {
            lock.lock()
            storage.removeAll()
            lock.unlock()
        }

        func remove(prefix: String) {
            lock.lock()
            storage = storage.filter { !$0.key.hasPrefix(prefix) }
            lock.unlock()
        }
    }

    private let descendantCache = DescendantCacheStore()
    
    init(folderURL: URL) {
        self.folderURL = folderURL
        self.id = "folder:\(folderURL.path)"
        self.name = folderURL.lastPathComponent
        self.icon = NSWorkspace.shared.icon(forFile: folderURL.path)
        self.expansionState = FolderExpansionState(sourceId: "folder:\(folderURL.path)")
        self.eventCoalescer = Throttler(minimumDelay: 0.15, queue: .main)
    }
    
    var items: [ContentItem] {
        if searchQuery.isEmpty { return cachedItems }
        return search(query: searchQuery)
    }

    func item(with id: UUID) -> ContentItem? {
        if let index = indexById[id], cachedItems.indices.contains(index) {
            return cachedItems[index]
        }
        return nil
    }

    func visibleChildren(of folderId: UUID) -> [ContentItem] {
        guard let folderIndex = indexById[folderId],
              cachedItems.indices.contains(folderIndex) else { return [] }

        let parent = cachedItems[folderIndex]
        guard parent.isFolder else { return [] }

        let childDepth = parent.depth + 1
        var result: [ContentItem] = []
        var i = folderIndex + 1

        while i < cachedItems.count {
            let candidate = cachedItems[i]
            if candidate.depth <= parent.depth { break }
            if candidate.depth == childDepth {
                result.append(candidate)
            }
            i += 1
        }

        return result
    }

    func descendantSnapshot(for folderId: UUID) -> HierarchyDescendantSnapshot {
        guard let folderItem = item(with: folderId),
              let folderURL = folderItem.fileURL else {
            return HierarchyDescendantSnapshot(items: [])
        }

        return descendantSnapshot(for: folderURL)
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        
        // Validate folder exists and is accessible
        guard FileManager.default.fileExists(atPath: folderURL.path) else {
            print("FileSystemSource: Cannot monitor non-existent folder: \(folderURL.path)")
            return
        }
        
        isMonitoring = true
        
        // Ensure we have security access
        _ = folderURL.startAccessingSecurityScopedResource()
        
        let since = lastEventIdForFolder() ?? FSEventStreamGetCurrentEventId()
        let config = FSEventsStream.Config(
            root: folderURL,
            sinceWhen: since,
            latency: 0.3,  // Slightly higher latency for stability
            flags: FSEventStreamCreateFlags(
                kFSEventStreamCreateFlagFileEvents |
                kFSEventStreamCreateFlagUseCFTypes |
                kFSEventStreamCreateFlagIgnoreSelf
            ),
            excludePaths: defaultExcludes(),
            queue: queue
        )
        
        stream = FSEventsStream(config: config) { [weak self] events in
            guard let self = self else { return }
            // Events are already coming in on the background queue
            // Just call ingest directly
            self.ingest(events)
        }
        stream?.start()
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        
        // Cancel any pending throttled operations
        eventCoalescer.cancel()
        pendingPaths.removeAll()
        
        // Stop and cleanup stream
        stream?.stop()
        stream = nil
        
        // Persist last event id
        persistLastEventId(FSEventStreamGetCurrentEventId())
        
        // Stop accessing security-scoped resource
        folderURL.stopAccessingSecurityScopedResource()
    }
    
    func refresh() async {
        await forceRefresh()
    }
    
    func refreshIfNeeded() async {
        // Only refresh if data is stale (older than refreshInterval)
        let timeSinceLastRefresh = Date().timeIntervalSince(lastRefreshTime)
        if timeSinceLastRefresh > refreshInterval {
            await forceRefresh()
        }
    }
    
    private func forceRefresh() async {
        // Mark decorators as needing refresh before updating items
        ContentManager.shared.markDecoratorsNeedRefresh(for: self.id)

#if DEBUG
        let refreshStart = Date()
#endif

        // Build hierarchical structure starting from root
        let hierarchicalItems = await buildHierarchicalItems(at: folderURL, depth: 0, parentPath: nil)
        self.cachedItems = hierarchicalItems
        self.lastRefreshTime = Date()
        self.rebuildIndexes()
        ContentManager.shared.markItemsDirty()
        ContentManager.shared.clearHiddenSelections(for: self.id, underPath: folderURL.path)
        // Visible slice changed; invalidate selectedItems cache
        ContentManager.shared.markSelectedDirty()
        invalidateDescendantCache(under: folderURL.path)

#if DEBUG
        let elapsed = Date().timeIntervalSince(refreshStart)
        Self.refreshLogger.debug("forceRefresh(\(self.folderURL.lastPathComponent, privacy: .public)) duration=\(elapsed, privacy: .public)s items=\(hierarchicalItems.count, privacy: .public)")
#endif
    }
    
    // Check if directory has been modified since last cache
    private func hasDirectoryChanged(at url: URL) -> Bool {
        let path = url.path
        let currentModDate = getDirectoryModificationDate(url)
        
        if let cachedModDate = directoryModDateCache[path] {
            return currentModDate > cachedModDate
        }
        
        // No cache entry means we haven't scanned this directory before
        return true
    }
    
    // Update directory modification date cache
    private func updateDirectoryModDateCache(at url: URL) {
        let path = url.path
        let modDate = getDirectoryModificationDate(url)
        directoryModDateCache[path] = modDate
    }
    
    // Get directory modification date
    private func getDirectoryModificationDate(_ url: URL) -> Date {
        let resourceValues = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        return resourceValues?.contentModificationDate ?? .distantPast
    }
    
    // Clear modification date cache for path and its children
    private func clearDirectoryModDateCache(for path: String? = nil) {
        if let specificPath = path {
            // Clear cache for specific path and any child directories
            directoryModDateCache = directoryModDateCache.filter { cachedPath, _ in
                !cachedPath.hasPrefix(specificPath)
            }
            invalidateDescendantCache(under: specificPath)
            ContentManager.shared.clearHiddenSelections(for: id, underPath: specificPath)
        } else {
            // Clear entire cache
            directoryModDateCache.removeAll()
            invalidateDescendantCache(under: folderURL.path)
            ContentManager.shared.clearHiddenSelections(for: id, underPath: folderURL.path)
        }
    }

    // MARK: - Localized refresh helpers

    @MainActor
    private func refreshFolderSlice(at folderPath: String) async {
        guard let folderIdx = indexByPath[folderPath],
              cachedItems.indices.contains(folderIdx),
              cachedItems[folderIdx].isFolder,
              let folderURL = cachedItems[folderIdx].fileURL else { return }

        let baseDepth = cachedItems[folderIdx].depth

        // Count the current contiguous descendants (until an item with depth <= baseDepth)
        var childCount = 0
        var i = folderIdx + 1
        while i < cachedItems.count, cachedItems[i].depth > baseDepth {
            childCount += 1
            i += 1
        }

        // Only rebuild children if this folder is expanded; otherwise remove slice
        let replacement: [ContentItem]
        if expansionState.isExpanded(folderPath) {
            replacement = await buildHierarchicalItems(
                at: folderURL,
                depth: baseDepth + 1,
                parentPath: folderURL.path
            )
        } else {
            replacement = []
        }

        // Replace the slice under this folder with the newly built children
        let start = folderIdx + 1
        let end = folderIdx + 1 + childCount
        if start <= end, start <= cachedItems.count {
            let safeEnd = min(end, cachedItems.count)
            cachedItems.replaceSubrange(start..<safeEnd, with: replacement)
        }
        rebuildIndexes()
        ContentManager.shared.markItemsDirty()
        // Visible slice changed; invalidate selectedItems cache and decorators cache
        ContentManager.shared.markDecoratorsNeedRefresh(for: self.id)
        ContentManager.shared.markSelectedDirty()
        invalidateDescendantCache(under: folderPath)
        ContentManager.shared.clearHiddenSelections(for: self.id, underPath: folderPath)
    }

    @MainActor
    private func nearestExpandedAncestor(of path: String) -> String? {
        var url = URL(fileURLWithPath: path).deletingLastPathComponent()
        while url.path.hasPrefix(folderURL.path) {
            if expansionState.isExpanded(url.path) { return url.path }
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        return nil
    }
    
    private func buildHierarchicalItems(
        at url: URL,
        depth: Int,
        parentPath: String?,
        expandedPaths: Set<String>? = nil
    ) async -> [ContentItem] {
        // Check if directory has changed before expensive scanning
        let hasChanged = await MainActor.run { self.hasDirectoryChanged(at: url) }

        // If directory hasn't changed and we have cached items for this path, return cached subset
        if !hasChanged && depth == 0 {
            // For root level, return existing cached items since directory is unchanged
            return await MainActor.run { self.cachedItems }
        }

        let expandedSet: Set<String>
        if let expandedPaths {
            expandedSet = expandedPaths
        } else {
            expandedSet = await MainActor.run { self.expansionState.getAllExpandedPaths() }
        }

        let (sortOrder, sortDirection) = await MainActor.run { (self.sortOrder, self.sortDirection) }
        let sourceId = "folder:\(self.folderURL.path)"

        let resourceKeys = Self.directoryResourceKeys
        let task = Task.detached { () -> [ContentItem] in
            let fm = FileManager.default
            guard let urls = try? fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsHiddenFiles]
            ) else { return [] }

            var folders: [DirectoryEntry] = []
            var files: [DirectoryEntry] = []
            folders.reserveCapacity(urls.count)
            files.reserveCapacity(urls.count)

            for itemURL in urls {
                if self.shouldExclude(filename: itemURL.lastPathComponent) {
                    continue
                }

                guard let resourceValues = try? itemURL.resourceValues(forKeys: resourceKeys) else { continue }
                let snapshot = FileIdentity.Snapshot(
                    identity: resourceValues.fileResourceIdentifier as? Data,
                    modDate: resourceValues.contentModificationDate ?? .distantPast,
                    isDirectory: resourceValues.isDirectory ?? false,
                    size: resourceValues.fileSize.map { Int64($0) }
                )

                if snapshot.isDirectory {
                    folders.append(DirectoryEntry(url: itemURL, snapshot: snapshot, typeIdentifier: nil))
                } else {
                    let typeIdentifier: String?
                    if let type = resourceValues.contentType {
                        typeIdentifier = type.identifier
                    } else {
                        typeIdentifier = Self.resolvedType(for: itemURL)?.identifier
                    }
                    files.append(DirectoryEntry(url: itemURL, snapshot: snapshot, typeIdentifier: typeIdentifier))
                }
            }

            folders.sort { Self.sortEntries($0, $1, order: sortOrder, direction: sortDirection) }
            files.sort { Self.sortEntries($0, $1, order: sortOrder, direction: sortDirection) }

            var items: [ContentItem] = []
            items.reserveCapacity(folders.count + files.count)

            for folder in folders {
                let uuid = Self.makeStableUUID(identity: folder.snapshot.identity, fallbackPath: folder.url.absoluteString)
                let folderItem = ContentItem(
                    id: uuid,
                    title: folder.url.lastPathComponent,
                    timestamp: folder.snapshot.modDate,
                    sourceType: .folder,
                    sourceId: sourceId,
                    fileURL: folder.url,
                    plainText: folder.url.path,
                    fileIdentity: folder.snapshot.identity,
                    isFolder: true,
                    depth: depth,
                    parentPath: parentPath
                )
                items.append(folderItem)
            }

            for file in files {
                let uuid = Self.makeStableUUID(identity: file.snapshot.identity, fallbackPath: file.url.absoluteString)
                let fileItem = ContentItem(
                    id: uuid,
                    title: file.url.lastPathComponent,
                    timestamp: file.snapshot.modDate,
                    sourceType: .folder,
                    sourceId: sourceId,
                    fileURL: file.url,
                    plainText: file.url.path,
                    fileIdentity: file.snapshot.identity,
                    uniformTypeIdentifier: file.typeIdentifier,
                    fileSize: file.snapshot.size,
                    isFolder: false,
                    depth: depth,
                    parentPath: parentPath
                )
                items.append(fileItem)
            }

            return items
        }

        let rootItems = await task.value
        var allItems: [ContentItem] = []
        
        for item in rootItems {
            allItems.append(item)
            
            // If it's a folder and should be expanded, add its children
            if item.isFolder,
               let folderURL = item.fileURL,
               depth < 3,
               expandedSet.contains(folderURL.path) {
                let childItems = await buildHierarchicalItems(
                    at: folderURL,
                    depth: depth + 1,
                    parentPath: folderURL.path,
                    expandedPaths: expandedSet
                )
                allItems.append(contentsOf: childItems)
            }
        }

        // Update directory modification date cache after successful scan
        await MainActor.run {
            self.updateDirectoryModDateCache(at: url)
        }
        
        return allItems
    }
    
    func search(query: String) -> [ContentItem] {
        cachedItems.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            ($0.plainText ?? "").localizedCaseInsensitiveContains(query)
        }
    }
    
    // Find items by their IDs, even if they're not currently visible (collapsed folders)
    func resolveItems(for ids: Set<UUID>) async -> [ContentItem] {
        guard !ids.isEmpty else { return [] }

        let baseURL = folderURL
        let sourceId = self.id
        let resourceKeys = Self.directoryResourceKeys

        return await Task.detached(priority: .utility) { () -> [ContentItem] in
            var foundItems: [ContentItem] = []
            let fm = FileManager.default

            guard let enumerator = fm.enumerator(
                at: baseURL,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsHiddenFiles]
            ) else { return [] }

            while let url = enumerator.nextObject() as? URL {
                guard let values = try? url.resourceValues(forKeys: resourceKeys) else { continue }
                let identity = values.fileResourceIdentifier as? Data
                let itemId = Self.makeStableUUID(identity: identity, fallbackPath: url.absoluteString)
                guard ids.contains(itemId) else { continue }

                let isDirectory = values.isDirectory == true
                let timestamp = values.contentModificationDate ?? Date()
                let uniformType = values.contentType?.identifier ?? (isDirectory ? nil : Self.resolvedType(for: url)?.identifier)
                let relativePath = url.path.replacingOccurrences(of: baseURL.path + "/", with: "")
                let depth = relativePath.components(separatedBy: "/").count
                let parentPath = url.deletingLastPathComponent().path

                let item = ContentItem(
                    id: itemId,
                    title: url.lastPathComponent,
                    timestamp: timestamp,
                    sourceType: .folder,
                    sourceId: sourceId,
                    fileURL: url,
                    uniformTypeIdentifier: uniformType,
                    fileSize: values.fileSize.map { Int64($0) },
                    isFolder: isDirectory,
                    depth: depth,
                    parentPath: parentPath == baseURL.path ? nil : parentPath,
                    isSelected: true
                )
                foundItems.append(item)

                if foundItems.count == ids.count {
                    break
                }
            }

            return foundItems
        }.value
    }
    
    // MARK: - Folder expansion methods
    
    func toggleFolderExpansion(at path: String) async {
        let wasExpanded = expansionState.isExpanded(path)
        expansionState.toggleExpansion(path)
        // Localized refresh: only rebuild the slice under this folder
        await refreshFolderSlice(at: path)
        
        // If we just expanded a folder, handle any selection state
        if !wasExpanded && expansionState.isExpanded(path) {
            ContentManager.shared.handleFolderExpansion(path)
        }
    }
    
    func isFolderExpanded(at path: String) -> Bool {
        expansionState.isExpanded(path)
    }
    
    // MARK: - Sorting Methods
    
    func setSortOrder(_ order: FileSortOrder, direction: FileSortDirection) {
        sortOrder = order
        sortDirection = direction
        clearDirectoryModDateCache() // Clear cache since sorting affects display
        Task {
            await forceRefresh()  // Force refresh when user explicitly changes sort
        }
    }

    private func invalidateDescendantCache(under path: String? = nil) {
        guard let path = path, !path.isEmpty else {
            descendantCache.removeAll()
            return
        }

        descendantCache.remove(prefix: normalizedFolderPath(path))
    }

    private nonisolated func isTextType(_ type: UTType?) -> Bool {
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

    private nonisolated func descendantSnapshot(for folderURL: URL) -> HierarchyDescendantSnapshot {
        let folderPath = normalizedFolderPath(folderURL.path)
        let modDate = (try? folderURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast

        if let cached = descendantCache.entry(for: folderPath), cached.modificationDate == modDate {
            return HierarchyDescendantSnapshot(items: cached.items)
        }

        var descendants: [HierarchyDescendantItem] = []
        let fm = FileManager.default
        if let enumerator = fm.enumerator(at: folderURL, includingPropertiesForKeys: [.isDirectoryKey, .contentTypeKey, .fileResourceIdentifierKey], options: [.skipsHiddenFiles]) {
            for case let url as URL in enumerator {
                do {
                    let values = try url.resourceValues(forKeys: [.isDirectoryKey, .contentTypeKey, .fileResourceIdentifierKey])
                    if values.isDirectory == true { continue }
                    let type = values.contentType ?? Self.resolvedType(for: url)
                    let snapshot = FileIdentity.snapshot(for: url)
                    let id = Self.makeStableUUID(identity: snapshot.identity, fallbackPath: url.absoluteString)
                    let isText = isTextType(type)
                    descendants.append(HierarchyDescendantItem(id: id, path: url.path, isText: isText))
                } catch {
                    continue
                }
            }
        }

        descendantCache.store(
            DescendantSnapshotCacheEntry(items: descendants, modificationDate: modDate),
            for: folderPath
        )

        return HierarchyDescendantSnapshot(items: descendants)
    }

    private nonisolated func normalizedFolderPath(_ path: String) -> String {
        path.hasSuffix("/") ? path : path + "/"
    }
    
    private nonisolated static func sortEntries(_ lhs: DirectoryEntry, _ rhs: DirectoryEntry, order: FileSortOrder, direction: FileSortDirection) -> Bool {
        let ascending: Bool

        switch order {
        case .name:
            ascending = lhs.url.lastPathComponent.localizedCompare(rhs.url.lastPathComponent) == .orderedAscending

        case .dateModified:
            ascending = lhs.snapshot.modDate < rhs.snapshot.modDate

        case .size:
            let lhsSize = lhs.snapshot.size ?? 0
            let rhsSize = rhs.snapshot.size ?? 0
            ascending = lhsSize < rhsSize

        case .type:
            let lhsType = lhs.typeIdentifier ?? lhs.url.pathExtension.lowercased()
            let rhsType = rhs.typeIdentifier ?? rhs.url.pathExtension.lowercased()
            ascending = lhsType.localizedCompare(rhsType) == .orderedAscending
        }

        return direction == .ascending ? ascending : !ascending
    }
}

// MARK: - UTType Resolution

extension FileSystemSource {
    // Generate a deterministic UUID from a file identity if present, otherwise from a stable string (path).
    nonisolated static func makeStableUUID(identity: Data?, fallbackPath: String) -> UUID {
        // Try to use identity data directly if available (much faster than SHA256)
        if let identity, identity.count >= 16 {
            // Use first 16 bytes of identity as UUID bytes
            let uuidBytes = Data(identity.prefix(16))
            let uuid = uuidBytes.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
                let bytePtr = bytes.bindMemory(to: UInt8.self)
                return UUID(uuid: (
                    bytePtr[0], bytePtr[1], bytePtr[2], bytePtr[3],
                    bytePtr[4], bytePtr[5], bytePtr[6], bytePtr[7],
                    bytePtr[8], bytePtr[9], bytePtr[10], bytePtr[11],
                    bytePtr[12], bytePtr[13], bytePtr[14], bytePtr[15]
                ))
            }
            return uuid
        }
        
        // Fallback: Use a simple hash of the path (faster than SHA256)
        // Create deterministic UUID from path using a simpler hash
        var hash: UInt64 = 5381
        for byte in fallbackPath.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        
        // Convert hash to UUID format
        let bytes = withUnsafeBytes(of: hash.bigEndian) { Array($0) }
        let padding = Array(repeating: UInt8(0), count: 8)
        let allBytes = bytes + padding
        
        return UUID(uuid: (
            allBytes[0], allBytes[1], allBytes[2], allBytes[3],
            allBytes[4], allBytes[5], allBytes[6], allBytes[7],
            allBytes[8], allBytes[9], allBytes[10], allBytes[11],
            allBytes[12], allBytes[13], allBytes[14], allBytes[15]
        ))
    }
    nonisolated static func resolvedType(for url: URL) -> UTType? {
        // Try to get type from resource values first
        if let vals = try? url.resourceValues(forKeys: [.contentTypeKey]),
           let t = vals.contentType {
            return t
        }
        // Fall back to extension-based detection
        if let t = UTType(filenameExtension: url.pathExtension) {
            return t
        }
        return nil
    }
}

// MARK: - FSEvents Event Processing

extension FileSystemSource {
    // This is called from background queue, not main actor
    nonisolated private func ingest(_ events: [FSEventsStream.Event]) {
        // Guard against empty events
        guard !events.isEmpty else { return }
        
        // Persist last event id first
        if let maxId = events.map(\.id).max() {
            persistLastEventId(maxId)
        }
        
        // Check for critical flags that require full rescan
        for event in events {
            if flagsRequireFullRescan(event.flags) {
                // Clear cache and schedule full refresh on main actor
                Task { @MainActor [weak self] in
                    self?.clearDirectoryModDateCache() // Clear entire cache
                    await self?.refresh()
                }
                return
            }
        }
        
        // Filter and accumulate relevant events
        let folderPath = folderURL.path
        var pathsToAdd: [String] = []
        
        for event in events {
            // Only process events within our folder
            guard event.path.hasPrefix(folderPath) else { continue }
            
            // Skip excluded paths based on user patterns
            if shouldExclude(path: event.path) {
                continue
            }
            
            pathsToAdd.append(event.path)
        }
        
        // Add paths to pending set on the main actor, then coalesce apply
        if !pathsToAdd.isEmpty {
            Task { @MainActor [weak self] in
                guard let self else { return }
                for path in pathsToAdd { self.pendingPaths.insert(path) }
                guard !self.pendingPaths.isEmpty else { return }
                self.eventCoalescer.throttle {
                    Task { @MainActor [weak self] in
                        self?.applyPending()
                    }
                }
            }
        }
    }
    
    @MainActor
    private func applyPending() {
        let paths = pendingPaths
        pendingPaths.removeAll()

        // Prefer localized refresh within the nearest expanded ancestor
        for p in paths {
            if let ancestor = nearestExpandedAncestor(of: p) {
                Task { @MainActor in
                    self.clearDirectoryModDateCache(for: ancestor) // Clear cache for ancestor path
                    await self.refreshFolderSlice(at: ancestor)
                }
                return
            }
        }

        // Fallback if nothing is expanded or we can't localize
        Task { @MainActor in
            self.clearDirectoryModDateCache() // Clear entire cache
            await self.refresh()
        }
    }
    
    func suspendResort(for id: UUID?, enabled: Bool) {
        suspendResortItemId = enabled ? id : nil
    }
    
    private func rebuildIndexes() {
        indexByIdentity.removeAll()
        indexByPath.removeAll()
        indexById.removeAll()

        for (i, item) in cachedItems.enumerated() {
            if let identity = item.fileIdentity {
                indexByIdentity[identity] = i
            }
            if let path = item.fileURL?.path {
                indexByPath[path] = i
            }
            indexById[item.id] = i
        }
    }
    
    nonisolated private func flagsRequireFullRescan(_ flags: FSEventStreamEventFlags) -> Bool {
        // kernel/user dropped, or "must rescan subdirs", or root changed
        return FSEventsStream.userDropped(flags) ||
               FSEventsStream.kernelDropped(flags) ||
               FSEventsStream.mustScanSubDirs(flags) ||
               FSEventsStream.rootChanged(flags)
    }
    
    private func scheduleFullRefresh() {
        pendingPaths.removeAll()
        Task { @MainActor in
            await refresh()
        }
    }
    
    private func defaultExcludes() -> [String] {
        // Use user-configured patterns, converting exact matches to full paths
        let patterns = Defaults[.ignoredFilePatterns]
        
        // Only convert exact patterns (no wildcards) to full paths for FSEvents exclusion
        // Wildcard patterns will be handled during scanning and event processing
        return patterns
            .filter { !$0.contains("*") && !$0.contains("?") }
            .map { folderURL.appendingPathComponent($0).path }
    }
    
    nonisolated private func lastEventIdForFolder() -> FSEventStreamEventId? {
        UserDefaults.standard.object(forKey: "FSEvents.lastId.\(id)") as? FSEventStreamEventId
    }
    
    nonisolated private func persistLastEventId(_ idValue: FSEventStreamEventId) {
        UserDefaults.standard.set(idValue, forKey: "FSEvents.lastId.\(id)")
    }
    
    // MARK: - Pattern Matching for File Exclusions
    
    private nonisolated func shouldExclude(path: String) -> Bool {
        let filename = URL(fileURLWithPath: path).lastPathComponent
        return shouldExclude(filename: filename)
    }
    
    private nonisolated func shouldExclude(filename: String) -> Bool {
        let patterns = Defaults[.ignoredFilePatterns]
        
        for pattern in patterns {
            if pattern.contains("*") || pattern.contains("?") {
                // Wildcard pattern matching using NSPredicate
                if matchesWildcardPattern(filename: filename, pattern: pattern) {
                    return true
                }
            } else {
                // Exact match
                if filename == pattern {
                    return true
                }
            }
        }
        return false
    }
    
    private nonisolated func matchesWildcardPattern(filename: String, pattern: String) -> Bool {
        // Convert shell-style wildcards to NSPredicate LIKE pattern
        let predicatePattern = pattern
            .replacingOccurrences(of: "*", with: "*")  // Keep * as is for LIKE
            .replacingOccurrences(of: "?", with: "?")  // Keep ? as is for LIKE
        
        let predicate = NSPredicate(format: "SELF LIKE %@", predicatePattern)
        return predicate.evaluate(with: filename)
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
