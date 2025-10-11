import AppKit
import Foundation
import ScreenCaptureKit

/// Represents a capturable window or screen
public struct WindowInfo: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let windowID: CGWindowID?
    public let displayID: CGDirectDisplayID?
    public let title: String
    public let owningApplication: String
    public let applicationBundleIdentifier: String?
    public let bounds: CGRect
    public let isDesktop: Bool

    public init(
        id: UUID,
        windowID: CGWindowID? = nil,
        displayID: CGDirectDisplayID? = nil,
        title: String,
        owningApplication: String,
        applicationBundleIdentifier: String? = nil,
        bounds: CGRect,
        isDesktop: Bool = false
    ) {
        self.id = id
        self.windowID = windowID
        self.displayID = displayID
        self.title = title
        self.owningApplication = owningApplication
        self.applicationBundleIdentifier = applicationBundleIdentifier
        self.bounds = bounds
        self.isDesktop = isDesktop
    }

    /// Create WindowInfo from SCWindow
    @available(macOS 12.3, *)
    public static func from(_ window: SCWindow) -> WindowInfo? {
        guard let app = window.owningApplication else {
            return nil
        }

        let appName = app.applicationName

        // Create deterministic UUID from window ID
        let windowIDString = String(format: "%08d", window.windowID)
        let paddedString = String(repeating: "0", count: max(0, 32 - windowIDString.count)) + windowIDString

        let part1 = String(paddedString.prefix(8))
        let part2 = String(paddedString.dropFirst(8).prefix(4))
        let part3 = String(paddedString.dropFirst(12).prefix(4))
        let part4 = String(paddedString.dropFirst(16).prefix(4))
        let part5 = String(paddedString.dropFirst(20).prefix(12))

        let formatted = "\(part1)-\(part2)-\(part3)-\(part4)-\(part5)"
        let uuid = UUID(uuidString: formatted) ?? UUID()

        let title = window.title ?? "Untitled Window"

        return WindowInfo(
            id: uuid,
            windowID: window.windowID,
            displayID: nil,
            title: title,
            owningApplication: appName,
            applicationBundleIdentifier: app.bundleIdentifier,
            bounds: window.frame,
            isDesktop: false
        )
    }

    /// Create WindowInfo for desktop/display
    @available(macOS 12.3, *)
    public static func forDisplay(_ display: SCDisplay, index: Int) -> WindowInfo {
        let displayName = index == 0 ? "Desktop" : "Desktop \(index + 1)"

        // Create deterministic UUID from display ID
        let displayIDString = String(format: "d%07d", display.displayID)
        let paddedString = String(repeating: "0", count: max(0, 32 - displayIDString.count)) + displayIDString

        let part1 = String(paddedString.prefix(8))
        let part2 = String(paddedString.dropFirst(8).prefix(4))
        let part3 = String(paddedString.dropFirst(12).prefix(4))
        let part4 = String(paddedString.dropFirst(16).prefix(4))
        let part5 = String(paddedString.dropFirst(20).prefix(12))

        let formatted = "\(part1)-\(part2)-\(part3)-\(part4)-\(part5)"
        let uuid = UUID(uuidString: formatted) ?? UUID()

        return WindowInfo(
            id: uuid,
            windowID: nil,
            displayID: display.displayID,
            title: displayName,
            owningApplication: "System",
            applicationBundleIdentifier: nil,
            bounds: CGRect(x: CGFloat(display.frame.origin.x), y: CGFloat(display.frame.origin.y),
                          width: CGFloat(display.width), height: CGFloat(display.height)),
            isDesktop: true
        )
    }

    /// Get app icon for this window
    public func getIcon() -> NSImage {
        if isDesktop {
            return NSImage(systemSymbolName: "desktopcomputer", accessibilityDescription: "Desktop")
                ?? NSImage(size: NSSize(width: 32, height: 32))
        }

        if let bundleId = applicationBundleIdentifier,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }

        return NSImage(systemSymbolName: "app.fill", accessibilityDescription: owningApplication)
            ?? NSImage(size: NSSize(width: 32, height: 32))
    }
}
