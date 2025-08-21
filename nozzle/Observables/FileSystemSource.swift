import AppKit
import UniformTypeIdentifiers
import CryptoKit
import Observation
import CoreServices

@Observable @MainActor
final class FileSystemSource: ContentSource {
    let id: String
    let name: String
    let icon: NSImage
    let type: ContentSourceType = .folder
    private let folderURL: URL
    private var cachedItems: [ContentItem] = []
    
    var isMonitoring: Bool = false
    var searchQuery: String = ""
    
    // FSEvents monitoring
    private var stream: FSEventsStream?
    private let queue = DispatchQueue(label: "org.conmeara.nozzle.fs.\(UUID().uuidString)")
    private var eventCoalescer: Throttler
    
    // Thread-safe pending paths storage
    private let pendingPathsLock = NSLock()
    nonisolated(unsafe) private var _pendingPaths: Set<String> = []
    
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
    
    init(folderURL: URL) {
        self.folderURL = folderURL
        self.id = "folder:\(folderURL.path)"
        self.name = folderURL.lastPathComponent
        self.icon = NSWorkspace.shared.icon(forFile: folderURL.path)
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
        // Scan directory off main thread
        let task = Task.detached { [folderURL] () -> [ContentItem] in
            let fm = FileManager.default
            guard let urls = try? fm.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { return [] }
            
            let items = urls.compactMap { url -> ContentItem? in
                let snap = FileIdentity.snapshot(for: url)
                guard !snap.isDirectory else { return nil }
                
                let stableIdString = "\(url.absoluteString):\(snap.modDate.timeIntervalSince1970)"
                let hash = SHA256.hash(data: Data(stableIdString.utf8))
                let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
                let truncatedHash = String(hashString.prefix(32))
                let formattedHash = truncatedHash.inserting("-", at: [8, 12, 16, 20])
                let uuid = UUID(uuidString: formattedHash) ?? UUID()
                
                return ContentItem(
                    id: uuid,
                    title: url.lastPathComponent,
                    timestamp: snap.modDate,
                    sourceType: .folder,
                    sourceId: "folder:\(folderURL.path)",
                    fileURL: url,
                    plainText: url.path,
                    fileIdentity: snap.identity
                )
            }
            
            return items.sorted { $0.timestamp > $1.timestamp }
        }
        
        let items = await task.value
        self.cachedItems = items
        self.rebuildIndexes()
    }
    
    func search(query: String) -> [ContentItem] {
        cachedItems.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            ($0.plainText ?? "").localizedCaseInsensitiveContains(query)
        }
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
        
        // Add paths to pending set
        if !pathsToAdd.isEmpty {
            pendingPathsLock.lock()
            for path in pathsToAdd {
                _pendingPaths.insert(path)
            }
            let hasPending = !_pendingPaths.isEmpty
            pendingPathsLock.unlock()
            
            // Only proceed if we have pending paths
            guard hasPending else { return }
            
            // Coalesce changes - schedule on main actor
            Task { @MainActor [weak self] in
                self?.eventCoalescer.throttle {
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
        
        var mutated = false
        var needsResort = false
        
        for path in paths {
            let url = URL(fileURLWithPath: path)
            
            if FileIdentity.exists(at: path) {
                let snap = FileIdentity.snapshot(for: url)
                guard !snap.isDirectory else { continue }
                
                // Try to find by identity first (rename/move)
                if let identity = snap.identity, let idx = indexByIdentity[identity] {
                    // Update existing item in place (title, url, timestamp)
                    let item = cachedItems[idx]
                    let newItem = ContentItem(
                        id: item.id, // keep stable UI id
                        title: url.lastPathComponent,
                        timestamp: snap.modDate,
                        sourceType: .folder,
                        sourceId: item.sourceId,
                        fileURL: url,
                        plainText: url.path,
                        fileIdentity: identity,
                        isSelected: item.isSelected,
                        isVisible: item.isVisible
                    )
                    cachedItems[idx] = newItem
                    needsResort = true
                    mutated = true
                } else if let idx = indexByPath[path] {
                    // Update existing file by path (modified)
                    let item = cachedItems[idx]
                    let newItem = ContentItem(
                        id: item.id,
                        title: url.lastPathComponent,
                        timestamp: snap.modDate,
                        sourceType: .folder,
                        sourceId: item.sourceId,
                        fileURL: url,
                        plainText: url.path,
                        fileIdentity: snap.identity,
                        isSelected: item.isSelected,
                        isVisible: item.isVisible
                    )
                    cachedItems[idx] = newItem
                    needsResort = true
                    mutated = true
                } else {
                    // New file: insert
                    let stableIdString = "\(url.absoluteString):\(snap.modDate.timeIntervalSince1970)"
                    let hash = SHA256.hash(data: Data(stableIdString.utf8))
                    let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
                    let truncatedHash = String(hashString.prefix(32))
                    let formattedHash = truncatedHash.inserting("-", at: [8, 12, 16, 20])
                    let uuid = UUID(uuidString: formattedHash) ?? UUID()
                    
                    let newItem = ContentItem(
                        id: uuid,
                        title: url.lastPathComponent,
                        timestamp: snap.modDate,
                        sourceType: .folder,
                        sourceId: self.id,
                        fileURL: url,
                        plainText: url.path,
                        fileIdentity: snap.identity
                    )
                    cachedItems.insert(newItem, at: 0) // temp prepend
                    mutated = true
                }
            } else {
                // File deleted: try to drop by path
                if let idx = indexByPath[path] {
                    cachedItems.remove(at: idx)
                    mutated = true
                }
            }
        }
        
        if mutated {
            // Rebuild index and resort by timestamp (newest first)
            rebuildIndexes()
            if needsResort {
                cachedItems.sort { $0.timestamp > $1.timestamp }
            }
        }
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