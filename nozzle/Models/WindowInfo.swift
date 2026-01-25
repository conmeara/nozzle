import AppKit
import CryptoKit
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

    /// Generate a stable UUID for a window identifier using SHA256 hashing
    static func stableIdentifier(forWindowID windowID: CGWindowID) -> UUID {
        stableIdentifier(namespace: "window", value: "\(windowID)")
    }

    /// Generate a stable UUID for a display identifier using SHA256 hashing
    static func stableIdentifier(forDisplayID displayID: CGDirectDisplayID) -> UUID {
        stableIdentifier(namespace: "display", value: "\(displayID)")
    }

    private static func stableIdentifier(namespace: String, value: String) -> UUID {
        let stableIdString = "\(namespace):\(value)"
        let digest = SHA256.hash(data: Data(stableIdString.utf8))
        return digest.withUnsafeBytes { buffer -> UUID in
            let bytes = buffer.bindMemory(to: UInt8.self)
            return UUID(uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3],
                bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11],
                bytes[12], bytes[13], bytes[14], bytes[15]
            ))
        }
    }

    /// Create WindowInfo from SCWindow
    @available(macOS 12.3, *)
    public static func from(_ window: SCWindow) -> WindowInfo? {
        guard let app = window.owningApplication else {
            return nil
        }

        let trimmedAppName = app.applicationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let appName = trimmedAppName.isEmpty
            ? (app.bundleIdentifier.isEmpty ? "Unknown Application" : app.bundleIdentifier)
            : trimmedAppName

        // Handle both nil and empty string titles
        let rawTitle = window.title ?? ""
        let title = rawTitle.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled Window" : rawTitle

        return WindowInfo(
            id: stableIdentifier(forWindowID: window.windowID),
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

        return WindowInfo(
            id: stableIdentifier(forDisplayID: display.displayID),
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
