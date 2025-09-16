import AppKit
import Observation
import UniformTypeIdentifiers

@Observable @MainActor
final class ClipboardSource: ContentSource {
    let id = "clipboard"
    let name = "Clipboard"
    let icon = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard")!
    let type: ContentSourceType = .clipboard
    
    private let history: History = History.shared      // existing model
    @ObservationIgnored private var cachedItems: [ContentItem] = []
    @ObservationIgnored private var cachedVersion: Int = -1
    @ObservationIgnored private var cachedMetadataVersion: Int = -1
    @ObservationIgnored private var metadataVersion: Int = 0
    @ObservationIgnored private var utiCache: [UUID: String?] = [:]
    @ObservationIgnored private var pendingUTIRequests: [UUID: Task<String?, Never>] = [:]
    var isMonitoring: Bool { true }                    // handled by Clipboard itself
    var searchQuery: String {
        get { history.searchQuery }
        set { history.searchQuery = newValue }          // leverage existing search
    }
    
    var items: [ContentItem] {
        let version = history.itemsRevision
        if version != cachedVersion || cachedMetadataVersion != metadataVersion {
            let decorators = history.items
            cachedItems = history.items.map { decorator in
                let uniformTypeIdentifier = uniformTypeIdentifier(for: decorator)
                return ContentItem(
                    id: decorator.id,
                    title: decorator.title,
                    timestamp: decorator.item.lastCopiedAt,
                    sourceType: .clipboard,
                    sourceId: id,
                    fileURL: decorator.item.fileURLs.first,
                    imageData: decorator.item.imageData,
                    rtfData: decorator.item.rtfData,
                    htmlData: decorator.item.htmlData,
                    plainText: decorator.item.text,
                    uniformTypeIdentifier: uniformTypeIdentifier,
                    applicationBundleId: decorator.item.application,
                    isSelected: decorator.isSelected,
                    isVisible: decorator.isVisible
                )
            }
            let activeIds = Set(decorators.map { $0.id })
            cleanupUTICache(keeping: activeIds)
            cachedVersion = version
            cachedMetadataVersion = metadataVersion
        }
        return cachedItems
    }
    
    func startMonitoring() {
        // Already handled by Clipboard
    }
    
    func stopMonitoring() {
        // Already handled by Clipboard
    }
    
    func refresh() async {
        // Clipboard refreshes automatically
    }
    
    func search(query: String) -> [ContentItem] {
        items.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }
}

private extension ClipboardSource {
    func uniformTypeIdentifier(for decorator: HistoryItemDecorator) -> String? {
        if let cached = utiCache[decorator.id] { return cached }

        guard let fileURL = decorator.item.fileURLs.first else {
            utiCache[decorator.id] = nil
            return nil
        }

        scheduleUTIResolution(for: decorator.id, fileURL: fileURL)
        return nil
    }

    func scheduleUTIResolution(for id: UUID, fileURL: URL) {
        guard pendingUTIRequests[id] == nil else { return }

        pendingUTIRequests[id] = Task.detached(priority: .utility) { [weak self] () -> String? in
            let identifier: String?
            if let values = try? fileURL.resourceValues(forKeys: [.contentTypeKey]) {
                identifier = values.contentType?.identifier
            } else {
                identifier = nil
            }

            if Task.isCancelled {
                await self?.clearPendingUTIRequest(for: id)
                return nil
            }

            await self?.applyResolvedUTI(identifier, for: id)

            return identifier
        }
    }

    func cleanupUTICache(keeping ids: Set<UUID>) {
        let staleCacheIds = utiCache.keys.filter { !ids.contains($0) }
        for key in staleCacheIds {
            utiCache.removeValue(forKey: key)
        }

        let staleTasks = pendingUTIRequests.keys.filter { !ids.contains($0) }
        for key in staleTasks {
            pendingUTIRequests[key]?.cancel()
            pendingUTIRequests.removeValue(forKey: key)
        }
    }

    @MainActor
    func clearPendingUTIRequest(for id: UUID) {
        pendingUTIRequests[id] = nil
    }

    @MainActor
    func applyResolvedUTI(_ identifier: String?, for id: UUID) {
        pendingUTIRequests[id] = nil
        utiCache[id] = identifier
        metadataVersion &+= 1
        ContentManager.shared.markItemsDirty()
        ContentManager.shared.markSelectedDirty()
        ContentManager.shared.markDecoratorsNeedRefresh(for: self.id)
    }
}
