import XCTest
@testable import nozzle

final class WindowInfoTests: XCTestCase {
    func testWindowStableIdentifierIsDeterministic() {
        let first = WindowInfo.stableIdentifier(forWindowID: 42)
        let second = WindowInfo.stableIdentifier(forWindowID: 42)

        XCTAssertEqual(first, second, "Stable identifiers for the same window ID should match.")
    }

    func testWindowStableIdentifiersAreDistinct() {
        let first = WindowInfo.stableIdentifier(forWindowID: 42)
        let second = WindowInfo.stableIdentifier(forWindowID: 100)

        XCTAssertNotEqual(first, second, "Different window IDs should map to different stable identifiers.")
    }

    func testDisplayStableIdentifierIsDeterministic() {
        let first = WindowInfo.stableIdentifier(forDisplayID: 1)
        let second = WindowInfo.stableIdentifier(forDisplayID: 1)

        XCTAssertEqual(first, second, "Stable identifiers for the same display ID should match.")
    }

    // MARK: - Window Filtering Tests

    @MainActor
    func testDesktopWindowsAreNotFiltered() {
        let source = ScreenshotSource()
        let desktopWindow = WindowInfo(
            id: UUID(),
            displayID: 1,
            title: "Desktop",
            owningApplication: "System",
            bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            isDesktop: true
        )

        XCTAssertNil(source.exclusionReason(for: desktopWindow), "Desktop windows should not be filtered")
    }

    @MainActor
    func testNozzleWindowsAreFiltered() {
        let source = ScreenshotSource()
        let nozzleWindow = WindowInfo(
            id: UUID(),
            windowID: 123,
            title: "Nozzle",
            owningApplication: "nozzle",
            applicationBundleIdentifier: Bundle.main.bundleIdentifier,
            bounds: CGRect(x: 0, y: 0, width: 600, height: 400),
            isDesktop: false
        )

        let reason = source.exclusionReason(for: nozzleWindow)
        XCTAssertNotNil(reason, "Nozzle's own windows should be filtered")
        XCTAssertTrue(reason?.contains("nozzle window") == true)
    }

    @MainActor
    func testSystemUIBundleIDsAreFiltered() {
        let source = ScreenshotSource()

        let systemBundleIds = [
            "com.apple.controlcenter",
            "com.apple.dock",
            "com.apple.WindowManager",
            "com.apple.systemuiserver",
            "com.apple.notificationcenterui",
            "com.apple.Spotlight"
        ]

        for bundleId in systemBundleIds {
            let window = WindowInfo(
                id: UUID(),
                windowID: 123,
                title: "System Window",
                owningApplication: "System",
                applicationBundleIdentifier: bundleId,
                bounds: CGRect(x: 0, y: 0, width: 200, height: 200),
                isDesktop: false
            )

            let reason = source.exclusionReason(for: window)
            XCTAssertNotNil(reason, "System UI with bundle ID \(bundleId) should be filtered")
            XCTAssertTrue(reason?.contains("system UI") == true)
        }
    }

    @MainActor
    func testSystemApplicationNamesAreFiltered() {
        let source = ScreenshotSource()

        let systemAppNames = [
            "Control Center",
            "Dock",
            "SystemUIServer",
            "Notification Center",
            "Window Server",
            "Spotlight"
        ]

        for appName in systemAppNames {
            let window = WindowInfo(
                id: UUID(),
                windowID: 123,
                title: "Window",
                owningApplication: appName,
                bounds: CGRect(x: 0, y: 0, width: 200, height: 200),
                isDesktop: false
            )

            let reason = source.exclusionReason(for: window)
            XCTAssertNotNil(reason, "System application '\(appName)' should be filtered")
            XCTAssertTrue(reason?.contains("system application") == true)
        }
    }

    @MainActor
    func testTooSmallWindowsAreFiltered() {
        let source = ScreenshotSource()

        // Too narrow
        let tooNarrow = WindowInfo(
            id: UUID(),
            windowID: 123,
            title: "Tiny",
            owningApplication: "App",
            bounds: CGRect(x: 0, y: 0, width: 20, height: 200),
            isDesktop: false
        )

        XCTAssertNotNil(source.exclusionReason(for: tooNarrow), "Windows narrower than 32px should be filtered")

        // Too short
        let tooShort = WindowInfo(
            id: UUID(),
            windowID: 124,
            title: "Tiny",
            owningApplication: "App",
            bounds: CGRect(x: 0, y: 0, width: 200, height: 20),
            isDesktop: false
        )

        XCTAssertNotNil(source.exclusionReason(for: tooShort), "Windows shorter than 32px should be filtered")

        // Just right
        let goodSize = WindowInfo(
            id: UUID(),
            windowID: 125,
            title: "Good",
            owningApplication: "App",
            bounds: CGRect(x: 0, y: 0, width: 200, height: 200),
            isDesktop: false
        )

        XCTAssertNil(source.exclusionReason(for: goodSize), "Windows 32px or larger should not be filtered by size")
    }

    @MainActor
    func testExtremeAspectRatiosAreFiltered() {
        let source = ScreenshotSource()

        // Too wide (menu bar item)
        let tooWide = WindowInfo(
            id: UUID(),
            windowID: 123,
            title: "Menu Bar Item",
            owningApplication: "App",
            bounds: CGRect(x: 0, y: 0, width: 1600, height: 100),
            isDesktop: false
        )

        let wideReason = source.exclusionReason(for: tooWide)
        XCTAssertNotNil(wideReason, "Windows with aspect ratio > 15 should be filtered")
        XCTAssertTrue(wideReason?.contains("aspect ratio too wide") == true)

        // Too narrow (status item)
        let tooNarrow = WindowInfo(
            id: UUID(),
            windowID: 124,
            title: "Status Item",
            owningApplication: "App",
            bounds: CGRect(x: 0, y: 0, width: 100, height: 1600),
            isDesktop: false
        )

        let narrowReason = source.exclusionReason(for: tooNarrow)
        XCTAssertNotNil(narrowReason, "Windows with aspect ratio < 0.067 should be filtered")
        XCTAssertTrue(narrowReason?.contains("aspect ratio too narrow") == true)
    }

    @MainActor
    func testMenuBarPositionWindowsAreFiltered() {
        let source = ScreenshotSource()

        let menuBarWindow = WindowInfo(
            id: UUID(),
            windowID: 123,
            title: "Menu Item",
            owningApplication: "App",
            bounds: CGRect(x: 100, y: 2, width: 100, height: 30),
            isDesktop: false
        )

        let reason = source.exclusionReason(for: menuBarWindow)
        XCTAssertNotNil(reason, "Windows at menu bar position should be filtered")
        XCTAssertTrue(reason?.contains("menu bar position") == true)
    }

    @MainActor
    func testGenericTitlePatternsAreFiltered() {
        let source = ScreenshotSource()

        // Test "Item-0" pattern
        let itemWindow = WindowInfo(
            id: UUID(),
            windowID: 123,
            title: "Item-0",
            owningApplication: "App",
            bounds: CGRect(x: 0, y: 0, width: 200, height: 200),
            isDesktop: false
        )

        let itemReason = source.exclusionReason(for: itemWindow)
        XCTAssertNotNil(itemReason, "Windows with 'Item-N' titles should be filtered")
        XCTAssertTrue(itemReason?.contains("generic item title") == true)

        // Test status window
        let statusWindow = WindowInfo(
            id: UUID(),
            windowID: 124,
            title: "App - Status",
            owningApplication: "App",
            bounds: CGRect(x: 0, y: 0, width: 200, height: 200),
            isDesktop: false
        )

        let statusReason = source.exclusionReason(for: statusWindow)
        XCTAssertNotNil(statusReason, "Windows with 'status' in title should be filtered")
        XCTAssertTrue(statusReason?.contains("status window") == true)

        // Test empty title
        let emptyTitleWindow = WindowInfo(
            id: UUID(),
            windowID: 125,
            title: "   ",
            owningApplication: "App",
            bounds: CGRect(x: 0, y: 0, width: 200, height: 200),
            isDesktop: false
        )

        let emptyReason = source.exclusionReason(for: emptyTitleWindow)
        XCTAssertNotNil(emptyReason, "Windows with empty titles should be filtered")
        XCTAssertTrue(emptyReason?.contains("empty title") == true)
    }

    @MainActor
    func testValidApplicationWindowsAreNotFiltered() {
        let source = ScreenshotSource()

        let validWindow = WindowInfo(
            id: UUID(),
            windowID: 123,
            title: "Document.txt",
            owningApplication: "TextEdit",
            applicationBundleIdentifier: "com.apple.TextEdit",
            bounds: CGRect(x: 100, y: 100, width: 800, height: 600),
            isDesktop: false
        )

        XCTAssertNil(source.exclusionReason(for: validWindow), "Valid application windows should not be filtered")
    }
}
