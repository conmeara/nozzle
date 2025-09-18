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
