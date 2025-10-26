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
}
