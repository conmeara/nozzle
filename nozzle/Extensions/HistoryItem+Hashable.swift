import Foundation

// Identity-based Hashable conformance for use in sets/maps
extension HistoryItem: Hashable {
  public static func == (lhs: HistoryItem, rhs: HistoryItem) -> Bool {
    return lhs === rhs
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}

