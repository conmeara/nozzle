import Foundation

public enum ContentSourceType: String, Sendable, CaseIterable {
    case clipboard
    case folder
    case screenshot
    // Future: notes, cloud, etc.
}