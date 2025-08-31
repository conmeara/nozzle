import AppKit
import UniformTypeIdentifiers
import CryptoKit
import Observation
import CoreServices

@Observable @MainActor
final class FileSystemSource: ContentSource {
    nonisolated let id: String  // Need nonisolated access for event persistence
    let name: String
    let icon: NSImage
    let type: ContentSourceType = .folder
    nonisolated let folderURL: URL  // Expose for bookmark cleanup and settings
    private var cachedItems: [ContentItem] = []
    
    // Folder expansion state
    private var expansionState: FolderExpansionState
    
    var isMonitoring: Bool = false
    var searchQuery: String = ""
    
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
        // Build hierarchical structure starting from root
        let hierarchicalItems = await buildHierarchicalItems(at: folderURL, depth: 0, parentPath: nil)
        self.cachedItems = hierarchicalItems
        self.rebuildIndexes()
        // Visible slice changed; invalidate selectedItems cache
        ContentManager.shared.markSelectedDirty()
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
        // Visible slice changed; invalidate selectedItems cache
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
        let task = Task.detached { () -> [ContentItem] in
            let fm = FileManager.default
            guard let urls = try? fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey, .fileSizeKey, .contentTypeKey],
                options: [.skipsHiddenFiles]
            ) else { return [] }
            
            var items: [ContentItem] = []
            let sourceId = "folder:\(self.folderURL.path)"
            
            // Separate folders and files
            var folders: [URL] = []
            var files: [URL] = []
            
            for itemURL in urls {
                let snap = FileIdentity.snapshot(for: itemURL)
                if snap.isDirectory {
                    folders.append(itemURL)
                } else {
                    files.append(itemURL)
                }
            }
            
            // Sort folders first, then files
            folders.sort { $0.lastPathComponent.localizedCompare($1.lastPathComponent) == .orderedAscending }
            files.sort { $0.lastPathComponent.localizedCompare($1.lastPathComponent) == .orderedAscending }
            
            // Add folders
            for folderURL in folders {
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
            for fileURL in files {
                let snap = FileIdentity.snapshot(for: fileURL)
                let type = Self.resolvedType(for: fileURL)
                let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize.flatMap(Int64.init)
                
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
}

// MARK: - UTType Resolution

extension FileSystemSource {
    // Generate a deterministic UUID from a file identity if present, otherwise from a stable string (path).
    nonisolated static func makeStableUUID(identity: Data?, fallbackPath: String) -> UUID {
        if let identity {
            let hash = SHA256.hash(data: identity)
            let hex = hash.compactMap { String(format: "%02x", $0) }.joined()
            let truncated = String(hex.prefix(32))
            let formatted = truncated.inserting("-", at: [8, 12, 16, 20])
            if let uuid = UUID(uuidString: formatted) { return uuid }
        }
        // Fallback: deterministic hash of absolute path (stable across saves)
        let hash = SHA256.hash(data: Data(fallbackPath.utf8))
        let hex = hash.compactMap { String(format: "%02x", $0) }.joined()
        let truncated = String(hex.prefix(32))
        let formatted = truncated.inserting("-", at: [8, 12, 16, 20])
        return UUID(uuidString: formatted) ?? UUID()
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
                // Schedule full refresh on main actor
                Task { @MainActor [weak self] in
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
            
            // Skip certain system paths even within our folder
            let relativePath = String(event.path.dropFirst(folderPath.count))
            guard !relativePath.contains("/.DS_Store"),
                  !relativePath.contains("/.git/"),
                  !relativePath.contains("/.svn/"),
                  !relativePath.contains("/.hg/") else {
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
                    await self.refreshFolderSlice(at: ancestor)
                }
                return
            }
        }

        // Fallback if nothing is expanded or we can't localize
        Task { @MainActor in
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
        // Keep simple for now; can be user-configurable later
        return [".DS_Store", ".git", "node_modules"].map { 
            folderURL.appendingPathComponent($0).path 
        }
    }
    
    nonisolated private func lastEventIdForFolder() -> FSEventStreamEventId? {
        UserDefaults.standard.object(forKey: "FSEvents.lastId.\(id)") as? FSEventStreamEventId
    }
    
    nonisolated private func persistLastEventId(_ idValue: FSEventStreamEventId) {
        UserDefaults.standard.set(idValue, forKey: "FSEvents.lastId.\(id)")
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
