import Foundation
import Observation
import OrderedCollections

@MainActor
@Observable
final class SelectionStore {
    private var orderedKeys = OrderedSet<ContentKey>()
    private(set) var selected = Set<ContentKey>()

    var isEmpty: Bool { selected.isEmpty }
    var orderedSelection: [ContentKey] {
        orderedKeys.filter { selected.contains($0) }
    }

    func insert(_ key: ContentKey) {
        guard selected.insert(key).inserted else { return }
        orderedKeys.append(key)
    }

    func contains(_ key: ContentKey) -> Bool {
        selected.contains(key)
    }

    func contains(itemId: UUID) -> Bool {
        selected.contains { $0.itemId == itemId }
    }

    func remove(_ key: ContentKey) {
        selected.remove(key)
    }

    func removeAll(forSourceId sourceId: String) {
        selected = Set(selected.filter { $0.sourceId != sourceId })
        orderedKeys = OrderedSet(orderedKeys.filter { $0.sourceId != sourceId })
    }

    func clearAll() {
        selected.removeAll()
        orderedKeys.removeAll(keepingCapacity: true)
    }
}
