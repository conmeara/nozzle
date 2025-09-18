import Foundation

public struct ContentKey: Hashable, Sendable, Codable {
    public let sourceId: String
    public let itemId: UUID

    public init(sourceId: String, itemId: UUID) {
        self.sourceId = sourceId
        self.itemId = itemId
    }
}
