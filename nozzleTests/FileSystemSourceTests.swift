import XCTest
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
    func testPermissionValidation_PreflightFalse_FetchFailsWrapsAsPermissionDenied() async {
        let source = ScreenshotSource()

        struct ProbeError: Error {}

        do {
            _ = try await source.withVerifiedScreenRecordingPermission(
                preflightCheck: { false },
                fetchContent: { throw ProbeError() }
            )
            XCTFail("Expected permission denied error to be thrown")
        } catch ScreenshotSource.ScreenRecordingAccessError.permissionDenied(let underlying) {
            XCTAssertTrue(underlying is ProbeError)
        } catch {
            XCTFail("Unexpected error type: \(error)")
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
