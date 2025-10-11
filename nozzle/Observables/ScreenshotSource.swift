import AppKit
import Foundation
import Observation
import ScreenCaptureKit
import OSLog

@Observable @MainActor
final class ScreenshotSource: ContentSource {
    private static let logger = Logger(subsystem: "org.conmeara.nozzle.content", category: "ScreenshotSource")

    let id: String = "screenshots"
    let name: String = "Screenshot"
    let icon: NSImage
    let type: ContentSourceType = .screenshot
    var isMonitoring: Bool = false
    var searchQuery: String = ""

    private var cachedItems: [ContentItem] = []
    private var windowInfoCache: [UUID: WindowInfo] = [:]
    private var thumbnailCache: [UUID: Data] = [:]

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

    func refresh() async {
        guard #available(macOS 12.3, *) else {
            Self.logger.error("ScreenCaptureKit requires macOS 12.3 or later")
            cachedItems = [createUnsupportedItem()]
            return
        }

        do {
            // Check for screen recording permission
            guard await checkScreenRecordingPermission() else {
                Self.logger.warning("Screen recording permission not granted")
                cachedItems = [createPermissionRequiredItem()]
                return
            }

            // Get shareable content (windows and displays)
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )

            var windowInfos: [WindowInfo] = []

            // Add desktop/displays first
            for (index, display) in content.displays.enumerated() {
                let info = WindowInfo.forDisplay(display, index: index)
                windowInfos.append(info)
            }

            // Add windows
            for window in content.windows {
                // Skip windows without titles or that are too small
                guard let info = WindowInfo.from(window),
                      window.frame.width >= 50 && window.frame.height >= 50 else {
                    continue
                }

                // Filter out system windows that shouldn't be captured
                let title = info.title.lowercased()
                let appName = info.owningApplication.lowercased()

                // Skip windows with problematic titles or missing app names
                if title.contains("backstop") ||
                   title.contains("wallpaper") ||
                   title.isEmpty ||
                   appName.isEmpty ||
                   appName == "window server" {
                    continue
                }

                windowInfos.append(info)
            }

            // Store window info for later capture
            windowInfoCache.removeAll()
            for info in windowInfos {
                windowInfoCache[info.id] = info
            }

            // Generate thumbnails in background
            await generateThumbnails(for: windowInfos, content: content)

            // Convert to ContentItems
            let items = windowInfos.map { info -> ContentItem in
                ContentItem(
                    id: info.id,
                    title: info.isDesktop ? info.title : "\(info.owningApplication) - \(info.title)",
                    timestamp: Date(),
                    sourceType: .screenshot,
                    sourceId: id,
                    imageData: thumbnailCache[info.id],
                    applicationBundleId: info.applicationBundleIdentifier
                )
            }

            cachedItems = items
            Self.logger.info("Refreshed screenshot source with \(items.count) items")

        } catch {
            Self.logger.error("Failed to get shareable content: \(error.localizedDescription)")
            cachedItems = [createErrorItem(error)]
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
        guard let windowInfo = windowInfoCache[itemId] else {
            Self.logger.error("Window info not found for id: \(itemId)")
            return nil
        }

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
                    Self.logger.error("Display not found for id: \(windowInfo.displayID ?? 0)")
                    return nil
                }
                filter = SCContentFilter(display: display, excludingWindows: [])
            } else {
                // Capture specific window
                guard let windowID = windowInfo.windowID,
                      let window = content.windows.first(where: { $0.windowID == windowID }) else {
                    Self.logger.error("Window not found for id: \(windowInfo.windowID ?? 0)")
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

    @available(macOS 12.3, *)
    private func generateThumbnails(for windowInfos: [WindowInfo], content: SCShareableContent) async {
        // Generate thumbnails with good preview resolution
        let config = SCStreamConfiguration()
        config.width = 1200
        config.height = 800
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

        for info in windowInfos {
            do {
                let filter: SCContentFilter

                if info.isDesktop {
                    guard let display = content.displays.first(where: { $0.displayID == info.displayID }) else {
                        continue
                    }
                    filter = SCContentFilter(display: display, excludingWindows: [])
                } else {
                    guard let windowID = info.windowID,
                          let window = content.windows.first(where: { $0.windowID == windowID }) else {
                        continue
                    }
                    filter = SCContentFilter(desktopIndependentWindow: window)
                }

                let thumbnail = try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: config
                )

                // Convert to PNG data
                let nsImage = NSImage(cgImage: thumbnail, size: NSSize(width: thumbnail.width, height: thumbnail.height))
                if let tiffData = nsImage.tiffRepresentation,
                   let bitmapImage = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                    thumbnailCache[info.id] = pngData
                }
            } catch {
                Self.logger.debug("Failed to generate thumbnail for \(info.title): \(error.localizedDescription)")
                // Continue with other thumbnails
            }
        }
    }

    @available(macOS 12.3, *)
    private func checkScreenRecordingPermission() async -> Bool {
        // Try to get shareable content - this will fail if permission is denied
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            return true
        } catch {
            return false
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
