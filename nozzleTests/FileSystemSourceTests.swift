import XCTest
import ScreenCaptureKit
@testable import nozzle

final class FileSystemSourceTests: XCTestCase {
    func testStableUUIDFallbackUsesSHA256() {
        let pathA = "file:///tmp/a.txt"
        let pathB = "file:///tmp/b.txt"

        let uuidA1 = FileSystemSource.makeStableUUID(identity: nil, fallbackPath: pathA)
        let uuidA2 = FileSystemSource.makeStableUUID(identity: nil, fallbackPath: pathA)
        let uuidB = FileSystemSource.makeStableUUID(identity: nil, fallbackPath: pathB)

        XCTAssertEqual(uuidA1, uuidA2)
        XCTAssertNotEqual(uuidA1, uuidB)
    }
}

final class ScreenshotSourcePermissionTests: XCTestCase {
    @MainActor
    func testPermissionValidation_PreflightTrue_FetchSucceeds() async throws {
        let source = ScreenshotSource()

        let result = try await source.withVerifiedScreenRecordingPermission(
            preflightCheck: { true },
            fetchContent: { "ok" }
        )

        XCTAssertTrue(result.permissionGranted)
        XCTAssertEqual(result.content, "ok")
    }

    @MainActor
    func testPermissionValidation_PreflightFalse_FetchSucceeds() async throws {
        let source = ScreenshotSource()

        let result = try await source.withVerifiedScreenRecordingPermission(
            preflightCheck: { false },
            fetchContent: { 42 }
        )

        XCTAssertTrue(result.permissionGranted)
        XCTAssertEqual(result.content, 42)
    }

    @MainActor
    func testPermissionValidation_PreflightFalse_UserDeclinedWrapsAsPermissionDenied() async {
        let source = ScreenshotSource()
        let declinedError = NSError(
            domain: SCStreamErrorDomain,
            code: SCStreamError.userDeclined.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "The user declined TCCs for application, window, display capture"]
        )

        do {
            _ = try await source.withVerifiedScreenRecordingPermission(
                preflightCheck: { false },
                fetchContent: { throw declinedError }
            )
            XCTFail("Expected permission denied error to be thrown")
        } catch ScreenshotSource.ScreenRecordingAccessError.permissionDenied(let underlying) {
            let nsError = underlying as NSError
            XCTAssertEqual(nsError.domain, SCStreamErrorDomain)
            XCTAssertEqual(nsError.code, SCStreamError.userDeclined.rawValue)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    @MainActor
    func testPermissionValidation_PreflightTrue_UserDeclinedPreservesOriginalError() async {
        let source = ScreenshotSource()
        let declinedError = NSError(
            domain: SCStreamErrorDomain,
            code: SCStreamError.userDeclined.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "The user declined TCCs for application, window, display capture"]
        )

        do {
            _ = try await source.withVerifiedScreenRecordingPermission(
                preflightCheck: { true },
                fetchContent: { throw declinedError }
            )
            XCTFail("Expected original fetch error to be thrown")
        } catch ScreenshotSource.ScreenRecordingAccessError.permissionDenied {
            XCTFail("Expected conflicting preflight/fetch results to preserve original error")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, SCStreamErrorDomain)
            XCTAssertEqual(nsError.code, SCStreamError.userDeclined.rawValue)
        }
    }

    @MainActor
    func testPermissionValidation_PreflightFlipsToGranted_UserDeclinedPreservesOriginalError() async {
        let source = ScreenshotSource()
        let declinedError = NSError(
            domain: SCStreamErrorDomain,
            code: SCStreamError.userDeclined.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "The user declined TCCs for application, window, display capture"]
        )
        var preflightCallCount = 0

        do {
            _ = try await source.withVerifiedScreenRecordingPermission(
                preflightCheck: {
                    defer { preflightCallCount += 1 }
                    return preflightCallCount > 0
                },
                fetchContent: { throw declinedError }
            )
            XCTFail("Expected original fetch error to be thrown")
        } catch ScreenshotSource.ScreenRecordingAccessError.permissionDenied {
            XCTFail("Expected postflight grant to preserve original error")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, SCStreamErrorDomain)
            XCTAssertEqual(nsError.code, SCStreamError.userDeclined.rawValue)
        }
    }

    @MainActor
    func testPermissionValidation_PreflightFalse_NonPermissionErrorPreserved() async {
        let source = ScreenshotSource()
        struct ProbeError: Error {}

        do {
            _ = try await source.withVerifiedScreenRecordingPermission(
                preflightCheck: { false },
                fetchContent: { throw ProbeError() }
            )
            XCTFail("Expected original fetch error to be thrown")
        } catch {
            XCTAssertTrue(error is ProbeError)
        }
    }

    @MainActor
    func testPermissionValidation_PreflightTrue_FetchFailsPreservesOriginalError() async {
        let source = ScreenshotSource()

        struct ProbeError: Error {}

        do {
            _ = try await source.withVerifiedScreenRecordingPermission(
                preflightCheck: { true },
                fetchContent: { throw ProbeError() }
            )
            XCTFail("Expected original fetch error to be thrown")
        } catch {
            XCTAssertTrue(error is ProbeError)
        }
    }
}
