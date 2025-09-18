import Foundation
import Observation
import OrderedCollections

@MainActor
@Observable
final class SelectionStore {
    private var orderedKeys = OrderedSet<ContentKey>()
    private(set) var selected = Set<ContentKey>()
    private(set) var examples = Set<ContentKey>()

    var isEmpty: Bool { selected.isEmpty }

    var orderedSelection: [ContentKey] {
        orderedKeys.filter { selected.contains($0) }
    }

    func insert(_ key: ContentKey) {
        guard selected.insert(key).inserted else { return }
        orderedKeys.append(key)
    }

    func insertManyPreservingOrder(_ keys: some Sequence<ContentKey>) {
        for key in keys where selected.insert(key).inserted {
            orderedKeys.append(key)
        }
    }

    func contains(_ key: ContentKey) -> Bool {
        selected.contains(key)
    }

    func contains(itemId: UUID) -> Bool {
        selected.contains { $0.itemId == itemId }
    }

    func remove(_ key: ContentKey) {
        selected.remove(key)
        examples.remove(key)
    }

    func addExample(_ key: ContentKey) {
        examples.insert(key)
    }

    func removeExample(_ key: ContentKey) {
        examples.remove(key)
    }

    func removeAll(forSourceId sourceId: String) {
        selected = Set(selected.filter { $0.sourceId != sourceId })
        orderedKeys = OrderedSet(orderedKeys.filter { $0.sourceId != sourceId })
        examples = Set(examples.filter { $0.sourceId != sourceId })
    }

    func clearAll() {
        selected.removeAll()
        examples.removeAll()
        orderedKeys.removeAll(keepingCapacity: true)
    }

    func toggleExample(_ key: ContentKey) {
        if examples.contains(key) {
            examples.remove(key)
        } else {
            examples.insert(key)
        }
    }

    func isExample(_ key: ContentKey) -> Bool {
        examples.contains(key)
    }
}
