import XCTest
import AppKit
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

        let hiddenId = stableUUID(for: hiddenFile)
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

        // Rename the hidden file and ensure the cached selection refreshes
        let renamedURL = nestedFolder.appendingPathComponent("february.txt")
        try FileManager.default.moveItem(at: hiddenFile, to: renamedURL)

        await source.refresh()

        let renameDeadline = Date().addingTimeInterval(2.0)
        var refreshedTitle: String?
        repeat {
            if let match = manager.selectedItems.first(where: { $0.id == hiddenId }) {
                if match.title == "february.txt" {
                    refreshedTitle = match.title
                    break
                }
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        } while Date() < renameDeadline

        XCTAssertEqual(refreshedTitle, "february.txt", "Renamed hidden selection should refresh cached metadata")
    }

    func testInsertionOrderStableAcrossResort() async {
        let manager = ContentManager.shared
        manager.resetForTesting()
        defer { manager.resetForTesting() }

        let itemA = makeItem(title: "Alpha", sourceId: "stub", plainText: "A")
        let itemB = makeItem(title: "Beta", sourceId: "stub", plainText: "B")
        let source = StubSource(id: "stub", items: [itemA, itemB])

        manager.registerSource(source)

        manager.toggleSelection(itemA.id)
        manager.toggleSelection(itemB.id)

        XCTAssertEqual(manager.selectedItems.map(\.id), [itemA.id, itemB.id])

        source.updateItems([itemB, itemA])
        manager.markItemsDirty()
        manager.markSelectedDirty()

        XCTAssertEqual(manager.selectedItems.map(\.id), [itemA.id, itemB.id])
    }

    func testDeselectionDoesNotReorder() async {
        let manager = ContentManager.shared
        manager.resetForTesting()
        defer { manager.resetForTesting() }

        let items = ["Alpha", "Beta", "Gamma", "Delta"].map { title in
            makeItem(title: title, sourceId: "stub", plainText: title)
        }
        let source = StubSource(id: "stub", items: items)
        manager.registerSource(source)

        manager.toggleSelection(items[0].id)
        manager.toggleSelection(items[1].id)
        manager.toggleSelection(items[2].id)

        manager.toggleSelection(items[1].id) // deselect Beta
        manager.toggleSelection(items[3].id) // select Delta

        XCTAssertEqual(manager.selectedItems.map(\.title), ["Alpha", "Gamma", "Delta"])
    }

    func testCollapsedFolderSelectAppendsDeterministically() async throws {
        let manager = ContentManager.shared
        manager.resetForTesting()
        defer { manager.resetForTesting() }

        let tempRoot = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let folder = tempRoot.appendingPathComponent("Docs", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let files = ["a.txt", "b.txt", "c.txt"].map { folder.appendingPathComponent($0) }
        try files.enumerated().forEach { index, url in
            try "file-\(index)".write(to: url, atomically: true, encoding: .utf8)
        }

        let source = FileSystemSource(folderURL: tempRoot)
        manager.registerSource(source)
        defer {
            source.stopMonitoring()
        }

        await source.refresh()

        guard let folderItem = source.items.first(where: { $0.fileURL == folder }) else {
            XCTFail("Expected folder item to be present")
            return
        }

        manager.toggleSelection(folderItem.id)

        let expectationDeadline = Date().addingTimeInterval(2)
        repeat {
            if manager.selectedItems.contains(where: { $0.fileURL == files.last }) {
                break
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        } while Date() < expectationDeadline

        let orderedTitles = manager.selectedItems.compactMap { $0.fileURL?.lastPathComponent }
        XCTAssertEqual(orderedTitles, ["Docs", "a.txt", "b.txt", "c.txt"])
    }

    func testCompositeKeyPreventsCollision() async {
        let manager = ContentManager.shared
        manager.resetForTesting()
        defer { manager.resetForTesting() }

        let sharedId = UUID()
        let firstItem = makeItem(title: "Alpha", id: sharedId, sourceId: "s1", plainText: "First")
        let secondItem = makeItem(title: "Alpha", id: sharedId, sourceId: "s2", plainText: "Second")

        let source1 = StubSource(id: "s1", items: [firstItem])
        let source2 = StubSource(id: "s2", items: [secondItem])
        manager.registerSource(source1)
        manager.registerSource(source2)

        manager.toggleSelection(firstItem.id)
        manager.toggleSelection(secondItem.id)

        let titlesBySource = Dictionary(uniqueKeysWithValues: manager.selectedItems.map { ($0.sourceId, $0.title) })
        XCTAssertEqual(titlesBySource["s1"], "Alpha")
        XCTAssertEqual(titlesBySource["s2"], "Alpha")
        XCTAssertEqual(manager.selectedItems.count, 2)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "ContentManagerSelectionTests-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeItem(title: String, id: UUID = UUID(), sourceId: String, plainText: String?) -> ContentItem {
        ContentItem(
            id: id,
            title: title,
            timestamp: Date(),
            sourceType: .clipboard,
            sourceId: sourceId,
            fileURL: nil,
            imageData: nil,
            rtfData: nil,
            htmlData: nil,
            plainText: plainText,
            fileIdentity: nil,
            uniformTypeIdentifier: nil,
            fileSize: nil,
            isFolder: false,
            depth: 0,
            parentPath: nil,
            applicationBundleId: nil
        )
    }

    private func stableUUID(for url: URL) -> UUID {
        let snapshot = FileIdentity.snapshot(for: url)
        return FileSystemSource.makeStableUUID(identity: snapshot.identity, fallbackPath: url.absoluteString)
    }
}

private final class StubSource: ContentSource {
    let id: String
    let name: String
    let icon: NSImage
    let type: ContentSourceType
    private(set) var storedItems: [ContentItem]

    var isMonitoring: Bool = false
    var searchQuery: String = ""

    var items: [ContentItem] { storedItems }

    init(id: String, type: ContentSourceType = .clipboard, items: [ContentItem]) {
        self.id = id
        self.name = id
        self.icon = NSImage(size: NSSize(width: 16, height: 16))
        self.type = type
        self.storedItems = items
    }

    func updateItems(_ newItems: [ContentItem]) {
        storedItems = newItems
    }

    func startMonitoring() {
        isMonitoring = true
    }

    func stopMonitoring() {
        isMonitoring = false
    }

    func refresh() async {}

    func search(query: String) -> [ContentItem] {
        if query.isEmpty { return storedItems }
        return storedItems.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }
}
