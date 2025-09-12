import SwiftUI
import KeyboardShortcuts
import Foundation

/// Observable provider for shortcut data that updates when shortcuts are customized
@Observable @MainActor
final class ShortcutsDataProvider {
    static let shared = ShortcutsDataProvider()
    
    /// Current shortcut categories with real-time data
    var categories: [ShortcutCategory] {
        // Return fresh data each time to ensure it reflects current shortcuts
        return ShortcutData.categories.map { category in
            ShortcutCategory(category.title, shortcuts: category.shortcuts)
        }
    }
    
    private init() {}
    
    /// Force refresh the categories (called when shortcuts change)
    func refresh() {
        // Trigger observable update by accessing categories
        _ = categories
    }
}

// MARK: - Notification Extension
extension NSNotification.Name {
    /// Notification sent when a keyboard shortcut changes
    static let shortcutDidChange = NSNotification.Name("ShortcutDidChange")
}

// MARK: - KeyboardShortcuts Extension
extension KeyboardShortcuts.Recorder {
    /// Custom recorder that posts notification when shortcut changes
    static func observableRecorder(for name: KeyboardShortcuts.Name) -> some View {
        KeyboardShortcuts.Recorder(for: name)
            .onAppear {
                // Initial notification
                NotificationCenter.default.post(name: .shortcutDidChange, object: nil)
            }
            .onChange(of: KeyboardShortcuts.getShortcut(for: name)) { _, _ in
                // Notify when shortcut changes
                NotificationCenter.default.post(name: .shortcutDidChange, object: nil)
            }
    }
}