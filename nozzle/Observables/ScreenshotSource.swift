import AppKit
import CoreGraphics
import Foundation
import Observation
import ScreenCaptureKit
import OSLog

@Observable @MainActor
final class ScreenshotSource: ContentSource {
    nonisolated private static let logger = Logger(subsystem: "org.conmeara.nozzle.content", category: "ScreenshotSource")

    enum ScreenRecordingAccessError: Error {
        case permissionDenied(underlying: Error)
    }

    /// Returns true only for explicit ScreenCaptureKit permission-denied failures.
    /// We intentionally avoid treating all preflight=false failures as permission
    /// errors because transient ScreenCaptureKit failures can occur for other reasons.
    private static func isPermissionDeniedError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == SCStreamErrorDomain,
           nsError.code == SCStreamError.userDeclined.rawValue {
            return true
        }

        // Fallback for older/localized surfaces where SCStreamError metadata may be lost.
        let lowered = nsError.localizedDescription.lowercased()
        return lowered.contains("declined") && lowered.contains("capture")
    }

    /// Check screen recording permission WITHOUT triggering a prompt
    /// Uses CGPreflightScreenCaptureAccess which is safe to call repeatedly
    /// - Returns: true if permission is granted, false otherwise
    nonisolated static func checkScreenRecordingPermission() -> Bool {
        // CGPreflightScreenCaptureAccess checks permission without triggering a prompt
        // This is safe to call repeatedly (e.g., in a timer)
        return CGPreflightScreenCaptureAccess()
    }

    /// Request screen recording permission (will trigger the system prompt)
    /// Only call this when user explicitly requests it (e.g., clicking "Grant" button)
    nonisolated static func requestScreenRecordingPermission() {
        // CGRequestScreenCaptureAccess triggers the system permission prompt
        // Only call this once when user explicitly requests permission
        _ = CGRequestScreenCaptureAccess()
    }

    /// Invalidates the cached permission state, forcing a fresh check on next access.
    /// Call this when permission state may have changed (e.g., user went to System Settings).
    func invalidatePermissionCache() {
        hasScreenRecordingPermission = nil
    }

    static let sourceID = "screenshots"
    let id: String = ScreenshotSource.sourceID
    let name: String = "Screenshot"
    let icon: NSImage
    let type: ContentSourceType = .screenshot
    var isMonitoring: Bool = false
    var searchQuery: String = ""

    private struct WindowRecord {
        var info: WindowInfo
        var lastSeen: Date
    }

    private var cachedItems: [ContentItem] = []
    private var windowRecords: [UUID: WindowRecord] = [:]
    private var orderedWindowIds: [UUID] = []
    private var thumbnailCacheKeys: Set<UUID> = []
    /// Grace period before removing windows from the list after they disappear.
    /// 12 seconds accommodates macOS window animation delays and prevents flickering
    /// when windows briefly disappear during animations or workspace transitions.
    private let staleWindowGracePeriod: TimeInterval = 12.0
    /// Minimum width/height for windows to be included in the screenshot list.
    /// 32px filters out tiny menu bar extras and status items while allowing
    /// legitimate small utility windows and floating palettes.
    private let minimumWindowDimension: CGFloat = 32.0
    /// Thumbnail width for preview images. 1200px provides good quality
    /// for high-DPI displays while maintaining reasonable memory usage.
    private let thumbnailWidth: Int = 1200
    /// Thumbnail height for preview images. 800px maintains a 3:2 aspect ratio
    /// and provides good quality for most window shapes.
    private let thumbnailHeight: Int = 800
    /// Timeout for individual thumbnail capture operations. 2 seconds prevents
    /// UI freezes from slow window capture while allowing time for complex windows.
    private let thumbnailCaptureTimeout: TimeInterval = 2.0
    /// Maximum aspect ratio for windows. 15:1 filters out wide menu bar items
    /// while allowing ultra-wide monitors and tiled window layouts.
    private let maxAspectRatio: CGFloat = 15.0
    /// Minimum aspect ratio for windows. 1:15 filters out tall status items
    /// and narrow panels while allowing legitimate vertical windows.
    private let minAspectRatio: CGFloat = 0.067  // 1/15
    /// Maximum Y coordinate for menu bar position check. Windows within 5px
    /// of top of screen with height < 50px are likely menu bar items.
    private let menuBarMaxY: CGFloat = 5.0
    /// Maximum height for menu bar items. 50px accommodates standard menu bar
    /// (25-44px) plus some margin while filtering out menu bar extras.
    private let menuBarMaxHeight: CGFloat = 50.0

    private let thumbnailCache: NSCache<NSUUID, NSData> = {
        let cache = NSCache<NSUUID, NSData>()
        cache.countLimit = 50 // Limit to 50 thumbnails
        cache.totalCostLimit = 100 * 1024 * 1024 // 100 MB limit
        return cache
    }()
    private var hasScreenRecordingPermission: Bool?

    /// Public accessor for permission state - true if granted, false if denied, nil if unknown
    var permissionState: Bool? { hasScreenRecordingPermission }

    /// Opens System Settings to the Screen Recording privacy pane
    func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
    private var lastRefreshTime: Date = .distantPast
    private let refreshInterval: TimeInterval = 5.0 // Refresh every 5 seconds when tab is active

    /// Placeholder thumbnail shown when capture fails. Provides consistent UX
    /// and visual feedback that the window exists even if capture failed.
    @ObservationIgnored
    private lazy var placeholderThumbnail: NSData? = {
        // Create a simple placeholder image with a camera icon
        let size = NSSize(width: thumbnailWidth, height: thumbnailHeight)
        let image = NSImage(size: size)

        image.lockFocus()
        // Light gray background
        NSColor(white: 0.95, alpha: 1.0).setFill()
        NSRect(origin: .zero, size: size).fill()

        // Draw camera icon in center if available
        if let cameraIcon = NSImage(systemSymbolName: "camera.metering.unknown", accessibilityDescription: nil) {
            let iconSize: CGFloat = 120
            let iconRect = NSRect(
                x: (size.width - iconSize) / 2,
                y: (size.height - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )
            cameraIcon.draw(in: iconRect)
        }
        image.unlockFocus()

        // Convert to PNG data
        if let tiffData = image.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapImage.representation(using: .png, properties: [:]) {
            return pngData as NSData
        }
        return nil
    }()

    init() {
        if let symbolImage = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "Screenshots") {
            self.icon = symbolImage
        } else {
            self.icon = NSImage(size: NSSize(width: 32, height: 32))
        }
    }

    var items: [ContentItem] {
        if searchQuery.isEmpty { return cachedItems }
        return search(query: searchQuery)
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        // Perform initial refresh
        Task {
            await refresh()
        }
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
    }

    func refreshIfNeeded(userInitiated: Bool = false) async {
        // Keep screenshot probing strictly user-initiated. If monitoring has not
        // been activated by selecting the Screenshot tab, skip all refreshes.
        guard isMonitoring else { return }

        // Explicit user actions (e.g., opening/reselecting Screenshot tab) should
        // be able to recover from stale/incorrect permission state immediately.
        if userInitiated {
            await refresh()
            return
        }

        // Avoid background probing from aggregated/non-screenshot views.
        if ContentManager.shared.activeSourceId != id {
            return
        }

        // After an explicit permission denial, avoid automatic retries that can
        // repeatedly re-trigger system prompts. Users can retry with explicit refresh.
        guard hasScreenRecordingPermission != false else { return }

        // Only refresh if data is stale (older than refreshInterval)
        let timeSinceLastRefresh = Date().timeIntervalSince(lastRefreshTime)
        if timeSinceLastRefresh > refreshInterval {
            await refresh()
        }
    }

    internal func withVerifiedScreenRecordingPermission<T>(
        preflightCheck: () -> Bool = ScreenshotSource.checkScreenRecordingPermission,
        fetchContent: () async throws -> T
    ) async throws -> (content: T, permissionGranted: Bool) {
        let preflightGranted = preflightCheck()

        do {
            let content = try await fetchContent()
            // On newer macOS versions we've observed CGPreflightScreenCaptureAccess()
            // occasionally report false while access is actually granted.
            if !preflightGranted {
                Self.logger.info("CGPreflight reported false but ScreenCaptureKit access succeeded; treating permission as granted")
            }
            return (content, true)
        } catch {
            let postflightGranted = preflightCheck()

            if Self.isPermissionDeniedError(error) {
                // Conflicting signals (preflight says granted, fetch says declined) are
                // treated as transient ScreenCaptureKit failures, not hard denial.
                if preflightGranted || postflightGranted {
                    let nsError = error as NSError
                    Self.logger.error(
                        "Permission-denied error conflicted with preflight granted domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public) preflightBefore=\(preflightGranted, privacy: .public) preflightAfter=\(postflightGranted, privacy: .public)"
                    )
                    throw error
                }
                throw ScreenRecordingAccessError.permissionDenied(underlying: error)
            }

            if preflightGranted || postflightGranted {
                throw error
            }

            // CGPreflight can report false even when access is not the actual failure.
            // Preserve non-permission errors so the UI can surface the real cause.
            let nsError = error as NSError
            Self.logger.error(
                "Preflight reported denied but fetch failed with non-permission error domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)"
            )
            throw error
        }
    }

    func refresh() async {
        guard #available(macOS 12.3, *) else {
            Self.logger.error("ScreenCaptureKit requires macOS 12.3 or later")
            cachedItems = [createUnsupportedItem()]
            return
        }

        do {
            // Verify permission using preflight + ScreenCaptureKit probing.
            let contentResult = try await withVerifiedScreenRecordingPermission {
                try await SCShareableContent.excludingDesktopWindows(
                    false,
                    onScreenWindowsOnly: true
                )
            }
            hasScreenRecordingPermission = contentResult.permissionGranted
            let content = contentResult.content

            let now = Date()
            var newOrderedIds: [UUID] = []
            var seenIds = Set<UUID>()
            var infosNeedingThumbnails: [WindowInfo] = []

            // Add desktop/displays first to keep them at the top of the list
            for (index, display) in content.displays.enumerated() {
                let info = WindowInfo.forDisplay(display, index: index)
                if register(info: info, seenAt: now) {
                    infosNeedingThumbnails.append(info)
                }
                if seenIds.insert(info.id).inserted {
                    newOrderedIds.append(info.id)
                }
            }

            Self.logger.debug("Total windows from ScreenCaptureKit: \(content.windows.count)")

            for window in content.windows {
                guard let info = WindowInfo.from(window) else {
                    Self.logger.debug("Filtered out window (missing owning application): \(window.title ?? "nil") [\(window.windowID)]")
                    continue
                }

                if let reason = exclusionReason(for: info) {
                    Self.logger.debug("Filtered out window (\(reason)): \(info.title) [\(info.owningApplication)]")
                    continue
                }

                if register(info: info, seenAt: now) {
                    infosNeedingThumbnails.append(info)
                }

                Self.logger.debug("Including window: \(info.title) [\(info.owningApplication)] ID:\(window.windowID) UUID:\(info.id)")
                if seenIds.insert(info.id).inserted {
                    newOrderedIds.append(info.id)
                }
            }

            if !orderedWindowIds.isEmpty {
                for id in orderedWindowIds where !seenIds.contains(id) {
                    if let record = windowRecords[id] {
                        if now.timeIntervalSince(record.lastSeen) <= staleWindowGracePeriod {
                            if seenIds.insert(id).inserted {
                                newOrderedIds.append(id)
                            }
                        } else {
                            windowRecords.removeValue(forKey: id)
                            thumbnailCache.removeObject(forKey: id as NSUUID)
                            Self.logger.debug("Pruned stale window: \(record.info.title)")
                        }
                    }
                }
            }

            orderedWindowIds = newOrderedIds

            // Prune stale thumbnails from cache to prevent unbounded memory growth
            // thumbnailCacheKeys tracks which IDs have cached thumbnails. When a window
            // is removed from the active set (closed or filtered), we remove its thumbnail
            // from NSCache and update our tracking set to match the current active windows.
            let activeKeySet = Set(newOrderedIds)
            let removedKeys = thumbnailCacheKeys.subtracting(activeKeySet)
            for id in removedKeys {
                thumbnailCache.removeObject(forKey: id as NSUUID)
            }
            thumbnailCacheKeys = activeKeySet

            await generateThumbnails(for: infosNeedingThumbnails, content: content)

            self.cachedItems = self.orderedWindowIds.compactMap { id -> ContentItem? in
                guard let record = self.windowRecords[id] else { return nil }
                let info = record.info
                let thumbnailData = self.thumbnailCache.object(forKey: id as NSUUID) as NSData?

                return ContentItem(
                    id: info.id,
                    title: info.isDesktop ? info.title : "\(info.owningApplication) - \(info.title)",
                    timestamp: record.lastSeen,
                    sourceType: .screenshot,
                    sourceId: self.id,
                    imageData: thumbnailData as Data?,
                    applicationBundleId: info.applicationBundleIdentifier
                )
            }

            lastRefreshTime = now
            Self.logger.info("Refreshed screenshot source with \(self.cachedItems.count) items (filtered from \(content.windows.count) windows)")

        } catch ScreenRecordingAccessError.permissionDenied(let error) {
            Self.logger.warning("Screen recording permission not granted: \(error.localizedDescription)")
            hasScreenRecordingPermission = false
            cachedItems = [createPermissionRequiredItem()]
            lastRefreshTime = Date()
            return
        } catch {
            Self.logger.error("Failed to get shareable content: \(error.localizedDescription)")
            // Reset permission cache on error (permissions may have been revoked)
            hasScreenRecordingPermission = nil
            cachedItems = [createErrorItem(error)]
            lastRefreshTime = Date()
        }
    }

    func search(query: String) -> [ContentItem] {
        cachedItems.filter {
            $0.title.localizedCaseInsensitiveContains(query)
        }
    }

    // MARK: - Screenshot Capture

    /// Capture a screenshot for a specific window or display
    @available(macOS 12.3, *)
    func captureScreenshot(for itemId: UUID) async -> NSImage? {
        guard let record = windowRecords[itemId] else {
            Self.logger.error("Window info not found for id: \(itemId)")
            return nil
        }

        let windowInfo = record.info
        windowRecords[itemId]?.lastSeen = Date()

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )

            let filter: SCContentFilter
            let config = SCStreamConfiguration()

            if windowInfo.isDesktop {
                // Capture display
                guard let display = content.displays.first(where: { $0.displayID == windowInfo.displayID }) else {
                    Self.logger.warning("Display no longer available for capture: \(windowInfo.displayID ?? 0)")
                    return nil
                }
                filter = SCContentFilter(display: display, excludingWindows: [])
            } else {
                // Capture specific window - may have closed since last refresh
                guard let windowID = windowInfo.windowID,
                      let window = content.windows.first(where: { $0.windowID == windowID }) else {
                    Self.logger.warning("Window '\(windowInfo.title)' no longer available (may have been closed)")
                    return nil
                }
                filter = SCContentFilter(desktopIndependentWindow: window)
            }

            // Capture at full resolution
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )

            return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))

        } catch {
            Self.logger.error("Failed to capture screenshot: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Private Helpers

    private func register(info: WindowInfo, seenAt timestamp: Date) -> Bool {
        let previous = windowRecords[info.id]
        windowRecords[info.id] = WindowRecord(info: info, lastSeen: timestamp)

        guard let previous else {
            return true
        }

        if thumbnailCache.object(forKey: info.id as NSUUID) == nil {
            return true
        }

        if previous.info.title == info.title,
           previous.info.owningApplication == info.owningApplication,
           previous.info.isDesktop == info.isDesktop,
           previous.info.bounds.equalTo(info.bounds) {
            return false
        }

        return true
    }

    internal func exclusionReason(for info: WindowInfo) -> String? {
        if info.isDesktop {
            return nil
        }

        // Filter out nozzle itself
        if info.applicationBundleIdentifier == Bundle.main.bundleIdentifier {
            return "nozzle window"
        }

        // Filter by bundle ID - most reliable method for system apps
        if let bundleId = info.applicationBundleIdentifier {
            let systemBundleIds: Set<String> = [
                "com.apple.controlcenter",
                "com.apple.dock",
                "com.apple.WindowManager",
                "com.apple.systemuiserver",
                "com.apple.notificationcenterui",
                "com.apple.Spotlight",
                "com.apple.CoreSimulator.SimulatorTrampoline"
            ]

            if systemBundleIds.contains(bundleId) {
                return "system UI (\(bundleId))"
            }
        }

        // Filter by application name (fallback for when bundle ID is unavailable)
        let loweredAppName = info.owningApplication.lowercased()
        let systemAppNames: Set<String> = [
            "control center",
            "dock",
            "systemuiserver",
            "notification center",
            "window server",
            "spotlight"
        ]

        if systemAppNames.contains(loweredAppName) {
            return "system application (\(info.owningApplication))"
        }

        // Filter by window size
        if info.bounds.width < minimumWindowDimension || info.bounds.height < minimumWindowDimension {
            return "window too small (\(Int(info.bounds.width))x\(Int(info.bounds.height)))"
        }

        // Filter by window aspect ratio (menu bar extras and status items)
        let aspectRatio = info.bounds.width / info.bounds.height
        if aspectRatio > maxAspectRatio {
            return "aspect ratio too wide (likely menu bar item)"
        }
        if aspectRatio < minAspectRatio {
            return "aspect ratio too narrow (likely status item)"
        }

        // Filter menu bar items by position and height
        // Menu bar is at top of screen (y ≈ 0) with typical height of ~25-44 pixels
        if info.bounds.origin.y <= menuBarMaxY && info.bounds.height < menuBarMaxHeight {
            return "menu bar position (y=\(Int(info.bounds.origin.y)), h=\(Int(info.bounds.height)))"
        }

        // Filter by title patterns
        let loweredTitle = info.title.lowercased()

        // Generic system titles
        if loweredTitle.contains("backstop") || loweredTitle.contains("wallpaper") {
            return "background wallpaper"
        }

        if loweredTitle == "menubar" || loweredTitle == "menu bar" {
            return "menu bar window"
        }

        // Generic "Item-0", "Item-1", etc. titles
        if loweredTitle.range(of: "^item-\\d+$", options: .regularExpression) != nil {
            return "generic item title"
        }

        // Status windows and floating indicators
        if loweredTitle == "status" || loweredTitle.hasSuffix(" - status") || loweredTitle.hasSuffix(" status") {
            return "status window"
        }

        // Other utility/non-content window patterns
        let utilityPatterns = [
            "^untitled window$",  // Generic untitled windows without content
            " - preferences$",    // Floating preferences panels (actual prefs windows usually have longer titles)
            " - settings$"        // Floating settings panels
        ]

        for pattern in utilityPatterns {
            if loweredTitle.range(of: pattern, options: .regularExpression) != nil {
                return "utility window (\(info.title))"
            }
        }

        // Very short or unhelpful titles (but allow single-char titles for some apps)
        if info.title.trimmingCharacters(in: .whitespaces).count == 0 {
            return "empty title"
        }

        return nil
    }

    @available(macOS 12.3, *)
    private func generateThumbnails(for windowInfos: [WindowInfo], content: SCShareableContent) async {
        guard !windowInfos.isEmpty else {
            Self.logger.debug("generateThumbnails called with empty windowInfos array")
            return
        }
        Self.logger.info("Generating thumbnails for \(windowInfos.count) windows")

        // Generate thumbnails with good preview resolution
        let config = SCStreamConfiguration()
        config.width = thumbnailWidth
        config.height = thumbnailHeight
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

        // NOTE: Serial processing is required because SCWindow and SCDisplay are not Sendable
        // in current ScreenCaptureKit API. Parallel processing with TaskGroup causes data races.
        // Future optimization: When ScreenCaptureKit types become Sendable, use TaskGroup for
        // concurrent thumbnail generation to improve performance.
        for info in windowInfos {
            Self.logger.debug("Generating thumbnail for: \(info.title)")
            let filter: SCContentFilter

            if info.isDesktop {
                guard let display = content.displays.first(where: { $0.displayID == info.displayID }) else {
                    Self.logger.warning("Display not found for thumbnail: \(info.title)")
                    continue
                }
                filter = SCContentFilter(display: display, excludingWindows: [])
            } else {
                guard let windowID = info.windowID,
                      let window = content.windows.first(where: { $0.windowID == windowID }) else {
                    Self.logger.warning("Window not found for thumbnail: \(info.title)")
                    continue
                }
                filter = SCContentFilter(desktopIndependentWindow: window)
            }

            // Capture with timeout to prevent UI freezes from slow windows
            // Use manual timeout check to avoid Sendable issues with non-Sendable SCStreamConfiguration
            let thumbnail: CGImage
            let captureTask = Task {
                try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: config
                )
            }

            // Wait for either completion or timeout
            let timeoutNanos = UInt64(thumbnailCaptureTimeout * 1_000_000_000)
            var didTimeout = false

            do {
                thumbnail = try await withThrowingTaskGroup(of: Result<CGImage, Error>.self) { group in
                    // Add capture task
                    group.addTask {
                        do {
                            let image = try await captureTask.value
                            return .success(image)
                        } catch {
                            return .failure(error)
                        }
                    }

                    // Add timeout task
                    group.addTask {
                        do {
                            try await Task.sleep(nanoseconds: timeoutNanos)
                            return .failure(NSError(domain: "ScreenshotSource", code: -1, userInfo: [NSLocalizedDescriptionKey: "Timeout"]))
                        } catch {
                            // Task was cancelled, return an error
                            return .failure(error)
                        }
                    }

                    // Get first result
                    guard let firstResult = try await group.next() else {
                        throw NSError(domain: "ScreenshotSource", code: -2, userInfo: [NSLocalizedDescriptionKey: "No result"])
                    }

                    // Cancel remaining tasks
                    group.cancelAll()

                    switch firstResult {
                    case .success(let image):
                        return image
                    case .failure(let error):
                        if error.localizedDescription == "Timeout" {
                            didTimeout = true
                        }
                        throw error
                    }
                }
            } catch {
                if didTimeout {
                    Self.logger.warning("Thumbnail capture timed out for \(info.title) after \(self.thumbnailCaptureTimeout)s")
                } else {
                    Self.logger.warning("Failed to generate thumbnail for \(info.title): \(error.localizedDescription)")
                }
                // Use placeholder thumbnail
                if let placeholder = placeholderThumbnail {
                    thumbnailCache.setObject(placeholder, forKey: info.id as NSUUID, cost: placeholder.length)
                }
                continue
            }

            // Convert to PNG data
            let nsImage = NSImage(cgImage: thumbnail, size: NSSize(width: thumbnail.width, height: thumbnail.height))
            if let tiffData = nsImage.tiffRepresentation,
               let bitmapImage = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                thumbnailCache.setObject(pngData as NSData, forKey: info.id as NSUUID, cost: pngData.count)
                Self.logger.debug("Cached thumbnail for \(info.title) (\(pngData.count) bytes)")
            } else {
                Self.logger.warning("Failed to convert thumbnail to PNG for \(info.title)")
            }
        }
    }

    // MARK: - Error States

    private func createPermissionRequiredItem() -> ContentItem {
        ContentItem(
            id: UUID(),
            title: "Screen Recording Permission Required",
            timestamp: Date(),
            sourceType: .screenshot,
            sourceId: id,
            plainText: "Please grant screen recording permission in System Settings > Privacy & Security > Screen Recording"
        )
    }

    private func createUnsupportedItem() -> ContentItem {
        ContentItem(
            id: UUID(),
            title: "macOS 12.3 or Later Required",
            timestamp: Date(),
            sourceType: .screenshot,
            sourceId: id,
            plainText: "Screenshot functionality requires macOS 12.3 or later"
        )
    }

    private func createErrorItem(_ error: Error) -> ContentItem {
        ContentItem(
            id: UUID(),
            title: "Error Loading Screenshots",
            timestamp: Date(),
            sourceType: .screenshot,
            sourceId: id,
            plainText: error.localizedDescription
        )
    }
}
