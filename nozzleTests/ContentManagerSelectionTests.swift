import XCTest
@testable import nozzle

@MainActor
final class ContentManagerSelectionTests: XCTestCase {
    func testHiddenSelectionPrefetchAddsFolderContext() async throws {
        let manager = ContentManager.shared
        manager.resetForTesting()

        let tempRoot = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let nestedFolder = tempRoot.appendingPathComponent("Reports", isDirectory: true)
        try FileManager.default.createDirectory(at: nestedFolder, withIntermediateDirectories: true)
        let hiddenFile = nestedFolder.appendingPathComponent("january.txt")
        try "budget".write(to: hiddenFile, atomically: true, encoding: .utf8)

        let source = FileSystemSource(folderURL: tempRoot)
        manager.registerSource(source)
        defer {
            source.stopMonitoring()
            manager.resetForTesting()
        }

        await source.refresh()

        XCTAssertFalse(
            source.items.contains(where: { $0.fileURL == hiddenFile }),
            "Nested file should stay hidden while folder is collapsed"
        )

        let hiddenId = manager.stableUUID(for: hiddenFile)
        manager.toggleSelection(hiddenId)

        var resolvedItem: ContentItem?
        let deadline = Date().addingTimeInterval(2.0)
        repeat {
            if let match = manager.selectedItems.first(where: { $0.id == hiddenId }) {
                resolvedItem = match
                break
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        } while Date() < deadline

        XCTAssertNotNil(resolvedItem, "Hidden selection should surface after background fetch")
        XCTAssertEqual(resolvedItem?.id, hiddenId)

        let folderItem = try XCTUnwrap(manager.selectedItems.first(where: { $0.isFolder }))
        XCTAssertEqual(folderItem.fileURL?.lastPathComponent, "Reports")

        guard
            let folderIndex = manager.selectedItems.firstIndex(where: { $0.id == folderItem.id }),
            let fileIndex = manager.selectedItems.firstIndex(where: { $0.id == hiddenId })
        else {
            XCTFail("Expected both folder and file in aggregated selection")
            return
        }
        XCTAssertLessThan(folderIndex, fileIndex)
        XCTAssertEqual(manager.selectedItems[fileIndex].id, hiddenId)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "ContentManagerSelectionTests-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
