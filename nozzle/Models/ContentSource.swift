import AppKit
import Foundation

@MainActor
public protocol ContentSource: AnyObject {
    var id: String { get }
    var name: String { get }
    var icon: NSImage { get }
    var type: ContentSourceType { get }
    var isMonitoring: Bool { get }
    var items: [ContentItem] { get }       // stable order, newest first
    var searchQuery: String { get set }    // each source may filter differently
    
    func startMonitoring()
    func stopMonitoring()
    func refresh() async
    func search(query: String) -> [ContentItem]
}

public struct HierarchyDescendantItem: Sendable {
    public init(id: UUID, path: String, isText: Bool) {
        self.id = id
        self.path = path
        self.isText = isText
    }

    public let id: UUID
    public let path: String
    public let isText: Bool
}

public struct HierarchyDescendantSnapshot: Sendable {
    public init(items: [HierarchyDescendantItem]) {
        self.items = items
    }

    public let items: [HierarchyDescendantItem]

    public var isEmpty: Bool { items.isEmpty }

    public var itemIds: [UUID] { items.map(\.id) }

    public var textItemIds: [UUID] {
        items.filter(\.isText).map(\.id)
    }
}

@MainActor
public protocol HierarchicalContentSource: ContentSource {
    func item(with id: UUID) -> ContentItem?
    func visibleChildren(of folderId: UUID) -> [ContentItem]
    func descendantSnapshot(for folderId: UUID) -> HierarchyDescendantSnapshot
    func resolveItems(for ids: Set<UUID>) async -> [ContentItem]
    func descendantTextItemIDs(for folderId: UUID) -> [UUID]
}

public extension HierarchicalContentSource {
    func descendantTextItemIDs(for folderId: UUID) -> [UUID] {
        descendantSnapshot(for: folderId).textItemIds
    }
}
