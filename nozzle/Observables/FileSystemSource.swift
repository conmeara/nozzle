import AppKit
import UniformTypeIdentifiers
import Observation
import CoreServices
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
final class FileSystemSource: ContentSource {
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
    
    // Resort suspension for stable editing
    private var suspendResortItemId: UUID?
    
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
        
        // Build hierarchical structure starting from root
        let hierarchicalItems = await buildHierarchicalItems(at: folderURL, depth: 0, parentPath: nil)
        self.cachedItems = hierarchicalItems
        self.lastRefreshTime = Date()
        self.rebuildIndexes()
        // Visible slice changed; invalidate selectedItems cache
        ContentManager.shared.markSelectedDirty()
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
        } else {
            // Clear entire cache
            directoryModDateCache.removeAll()
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
        // Visible slice changed; invalidate selectedItems cache and decorators cache
        ContentManager.shared.markDecoratorsNeedRefresh(for: self.id)
        ContentManager.shared.markSelectedDirty()
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
    
    private func buildHierarchicalItems(at url: URL, depth: Int, parentPath: String?) async -> [ContentItem] {
        // Check if directory has changed before expensive scanning
        let hasChanged = await MainActor.run { self.hasDirectoryChanged(at: url) }
        
        // If directory hasn't changed and we have cached items for this path, return cached subset
        if !hasChanged && depth == 0 {
            // For root level, return existing cached items since directory is unchanged
            return await MainActor.run { self.cachedItems }
        }
        
        let task = Task.detached { () -> [ContentItem] in
            let fm = FileManager.default
            // Only fetch isDirectory initially to separate folders/files
            guard let urls = try? fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { return [] }
            
            var items: [ContentItem] = []
            let sourceId = "folder:\(self.folderURL.path)"
            
            // Separate folders and files with minimal metadata
            var folders: [(url: URL, isDir: Bool)] = []
            var files: [(url: URL, isDir: Bool)] = []
            
            for itemURL in urls {
                // Skip excluded files/folders based on user patterns
                if self.shouldExclude(filename: itemURL.lastPathComponent) {
                    continue
                }
                
                let isDir = (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                if isDir {
                    folders.append((itemURL, isDir))
                } else {
                    files.append((itemURL, isDir))
                }
            }
            
            // Sort folders first, then files
            let sortOrder = await MainActor.run { self.sortOrder }
            let sortDirection = await MainActor.run { self.sortDirection }
            
            folders.sort { self.sortFiles($0.url, $1.url, order: sortOrder, direction: sortDirection) }
            files.sort { self.sortFiles($0.url, $1.url, order: sortOrder, direction: sortDirection) }
            
            // Add folders
            for (folderURL, _) in folders {
                // Fetch metadata once per folder
                let snap = FileIdentity.snapshot(for: folderURL)
                // Derive a stable UUID from the file identity when available;
                // fall back to absolute path for determinism (not mod date).
                let uuid = Self.makeStableUUID(identity: snap.identity, fallbackPath: folderURL.absoluteString)
                
                let folderItem = ContentItem(
                    id: uuid,
                    title: folderURL.lastPathComponent,
                    timestamp: snap.modDate,
                    sourceType: .folder,
                    sourceId: sourceId,
                    fileURL: folderURL,
                    plainText: folderURL.path,
                    fileIdentity: snap.identity,
                    isFolder: true,
                    depth: depth,
                    parentPath: parentPath
                )
                items.append(folderItem)
            }
            
            // Add files
            for (fileURL, _) in files {
                // Fetch metadata once per file
                let snap = FileIdentity.snapshot(for: fileURL)
                let type = Self.resolvedType(for: fileURL)
                // File size is already fetched in snap
                let fileSize = snap.size
                
                // Use stable identity-based UUID to prevent ID churn on save.
                let uuid = Self.makeStableUUID(identity: snap.identity, fallbackPath: fileURL.absoluteString)
                
                let fileItem = ContentItem(
                    id: uuid,
                    title: fileURL.lastPathComponent,
                    timestamp: snap.modDate,
                    sourceType: .folder,
                    sourceId: sourceId,
                    fileURL: fileURL,
                    plainText: fileURL.path,
                    fileIdentity: snap.identity,
                    uniformTypeIdentifier: type?.identifier,
                    fileSize: fileSize,
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
               depth < 3 { // Max depth limit
                
                // Check if this folder is expanded
                let shouldExpand = await MainActor.run {
                    return self.expansionState.isExpanded(folderURL.path)
                }
                
                if shouldExpand {
                    let childItems = await buildHierarchicalItems(
                        at: folderURL,
                        depth: depth + 1,
                        parentPath: folderURL.path
                    )
                    allItems.append(contentsOf: childItems)
                }
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
    
    private nonisolated func sortFiles(_ file1: URL, _ file2: URL, order: FileSortOrder, direction: FileSortDirection) -> Bool {
        let result: Bool
        
        switch order {
        case .name:
            result = file1.lastPathComponent.localizedCompare(file2.lastPathComponent) == .orderedAscending
            
        case .dateModified:
            let date1 = (try? file1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            let date2 = (try? file2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            result = date1 < date2
            
        case .size:
            let size1 = (try? file1.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            let size2 = (try? file2.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            result = size1 < size2
            
        case .type:
            let ext1 = file1.pathExtension.lowercased()
            let ext2 = file2.pathExtension.lowercased()
            result = ext1.localizedCompare(ext2) == .orderedAscending
        }
        
        return direction == .ascending ? result : !result
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
        
        for (i, item) in cachedItems.enumerated() {
            if let identity = item.fileIdentity {
                indexByIdentity[identity] = i
            }
            if let path = item.fileURL?.path {
                indexByPath[path] = i
            }
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
