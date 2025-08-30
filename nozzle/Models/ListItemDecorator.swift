import Foundation
import SwiftUI
import AppKit

/// Common protocol for all list item decorators
@MainActor
protocol ListItemDecorator: Observable, Identifiable, Hashable {
    var id: UUID { get }
    var title: String { get }
    var isVisible: Bool { get set }
    var isSelected: Bool { get }
    
    // Optional properties that may not apply to all decorators
    var attributedTitle: AttributedString? { get }
    var shortcuts: [KeyShortcut] { get }
    var appIcon: ApplicationImage? { get }
    var image: NSImage? { get }
    var accessoryImage: NSImage? { get }
    var isPinned: Bool { get }
    
    // Actions
    func copyToClipboard()
}

// Default implementations for optional properties
extension ListItemDecorator {
    var attributedTitle: AttributedString? { nil }
    var shortcuts: [KeyShortcut] { [] }
    var appIcon: ApplicationImage? { nil }
    var image: NSImage? { nil }
    var accessoryImage: NSImage? { nil }
    var isPinned: Bool { false }
}