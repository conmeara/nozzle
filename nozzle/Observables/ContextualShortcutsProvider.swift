import Foundation
import KeyboardShortcuts

/// Provides contextual keyboard shortcuts based on current app state
@Observable @MainActor
final class ContextualShortcutsProvider {
    static let shared = ContextualShortcutsProvider()

    private init() {}

    /// Represents a contextual shortcut with priority for ordering
    struct ContextualShortcut: Identifiable {
        let id = UUID()
        let keys: [KeyComponent]
        let description: String
        let priority: Int

        init(keys: [KeyComponent], description: String, priority: Int = 0) {
            self.keys = keys
            self.description = description
            self.priority = priority
        }
    }

    /// Get contextual shortcuts based on current app state
    func getContextualShortcuts(
        isSearchMode: Bool,
        hasSelection: Bool,
        hasInput: Bool,
        hasChips: Bool,
        activeTab: String,
        selectionCount: Int
    ) -> [ContextualShortcut] {
        var shortcuts: [ContextualShortcut] = []

        // Primary action shortcuts (highest priority)
        if !isSearchMode {
            // Prompt mode - always show "Paste Combined"
            shortcuts.append(ContextualShortcut(
                keys: [.special("⏎")],
                description: "Paste Combined",
                priority: 100
            ))

            if hasSelection || hasInput || hasChips {
                shortcuts.append(ContextualShortcut(
                    keys: [.modifier("⌘"), .special("⏎")],
                    description: "Paste Single Item",
                    priority: 95
                ))
            }
        } else {
            // Search mode
            shortcuts.append(ContextualShortcut(
                keys: [.special("⏎")],
                description: "Copy Text",
                priority: 100
            ))
        }

        // Selection shortcuts
        if activeTab == "prompts" {
            shortcuts.append(ContextualShortcut(
                keys: [.special("Tab")],
                description: "Add as Chip",
                priority: 80
            ))
        } else {
            shortcuts.append(ContextualShortcut(
                keys: [.special("Tab")],
                description: hasSelection ? "Deselect" : "Select",
                priority: 80
            ))
        }

        // Clear selection (only if there are selections or input)
        if (hasSelection || hasInput || hasChips) && !isSearchMode {
            shortcuts.append(ContextualShortcut(
                keys: [.modifier("⌘"), .special("⌫")],
                description: "Clear",
                priority: 75
            ))
        }

        // Mode switching
        if !isSearchMode {
            shortcuts.append(ContextualShortcut(
                keys: [.modifier("⌘"), .key("F")],
                description: "Search",
                priority: 60
            ))
        } else {
            shortcuts.append(ContextualShortcut(
                keys: [.modifier("⌘"), .key("F")],
                description: "Prompt Mode",
                priority: 60
            ))
        }

        // Navigation shortcuts (lower priority)
        shortcuts.append(ContextualShortcut(
            keys: [.special("↑"), .special("↓")],
            description: "Navigate",
            priority: 50
        ))

        // Global shortcuts (always available but low priority)
        shortcuts.append(ContextualShortcut(
            keys: [.special("Esc")],
            description: "Close",
            priority: 30
        ))

        // Sort by priority (highest first) and return top 4
        return Array(shortcuts.sorted { $0.priority > $1.priority }.prefix(4))
    }

    /// Get shortcuts for specific contexts (prompts tab, aggregated view, etc.)
    func getTabSpecificShortcuts(activeTab: String) -> [ContextualShortcut] {
        switch activeTab {
        case "prompts":
            return [
                ContextualShortcut(
                    keys: [.modifier("⌘"), .special("⏎")],
                    description: "Paste Prompt",
                    priority: 100
                ),
                ContextualShortcut(
                    keys: [.special("Tab")],
                    description: "Add as Chip",
                    priority: 90
                ),
                ContextualShortcut(
                    keys: [.modifier("⌘"), .key("P")],
                    description: "Exit Prompts",
                    priority: 80
                )
            ]
        case "aggregated":
            return [
                ContextualShortcut(
                    keys: [.special("⏎")],
                    description: "Paste All",
                    priority: 100
                ),
                ContextualShortcut(
                    keys: [.modifier("⌘"), .special("⏎")],
                    description: "Paste Single Item",
                    priority: 90
                ),
                ContextualShortcut(
                    keys: [.modifier("⌘"), .special("⌫")],
                    description: "Clear Selection",
                    priority: 80
                )
            ]
        default:
            return []
        }
    }
}