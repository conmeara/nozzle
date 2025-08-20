import Foundation

public enum ContentSourceType: String, Sendable, CaseIterable {
    case clipboard
    case folder
    // Future: notes, screenshots, cloud, etc.
}