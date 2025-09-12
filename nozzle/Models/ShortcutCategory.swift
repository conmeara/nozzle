import Foundation

/// Key component types for keyboard shortcuts
enum KeyComponent: Equatable, Hashable {
    case modifier(String)  // ⌘, ⌥, ⌃, ⇧
    case key(String)       // Letter, number, or symbol
    case special(String)   // ⏎, ⌫, Esc, Space, Tab
    
    var displayText: String {
        switch self {
        case .modifier(let text), .key(let text), .special(let text):
            return text
        }
    }
}

/// Individual shortcut item
struct ShortcutItem: Identifiable, Hashable {
    let id = UUID()
    let description: String
    let keys: [KeyComponent]
    
    init(_ description: String, keys: KeyComponent...) {
        self.description = description
        self.keys = Array(keys)
    }
}

/// Category of keyboard shortcuts
struct ShortcutCategory: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let shortcuts: [ShortcutItem]
    
    init(_ title: String, shortcuts: [ShortcutItem]) {
        self.title = title
        self.shortcuts = shortcuts
    }
}

/// Static data for all keyboard shortcuts in the app
enum ShortcutData {
    static let categories: [ShortcutCategory] = [
        ShortcutCategory("Global", shortcuts: [
            ShortcutItem("Open nozzle", keys: .modifier("⌥"), .key("V")),
            ShortcutItem("Close popup", keys: .special("Esc")),
            ShortcutItem("Open preferences", keys: .modifier("⌘"), .key(",")),
            ShortcutItem("Show keyboard shortcuts", keys: .modifier("⌘"), .key("/")),
            ShortcutItem("Open prompts", keys: .modifier("⌘"), .key("P"))
        ]),
        
        ShortcutCategory("Navigation", shortcuts: [
            ShortcutItem("Move up", keys: .special("↑")),
            ShortcutItem("Move down", keys: .special("↓")),
            ShortcutItem("Move to first", keys: .modifier("⌘"), .special("↑")),
            ShortcutItem("Move to last", keys: .modifier("⌘"), .special("↓")),
            ShortcutItem("Previous tab", keys: .modifier("⌘"), .key("[")),
            ShortcutItem("Next tab", keys: .modifier("⌘"), .key("]")),
            ShortcutItem("Previous tab page", keys: .modifier("⌘"), .modifier("⇧"), .key("[")),
            ShortcutItem("Next tab page", keys: .modifier("⌘"), .modifier("⇧"), .key("]"))
        ]),
        
        ShortcutCategory("Selection & Management", shortcuts: [
            ShortcutItem("Toggle selection", keys: .special("Space")),
            ShortcutItem("Select numbered", keys: .modifier("⌘"), .key("1-9")),
            ShortcutItem("Clear selection", keys: .modifier("⌘"), .special("⌫")),
            ShortcutItem("Pin/Unpin item", keys: .modifier("⌥"), .key("P")),
            ShortcutItem("Delete item", keys: .modifier("⌥"), .special("⌫"))
        ]),
        
        ShortcutCategory("Paste Operations", shortcuts: [
            ShortcutItem("Paste combined", keys: .special("⏎")),
            ShortcutItem("Paste current item", keys: .modifier("⌘"), .special("⏎")),
            ShortcutItem("Paste numbered", keys: .modifier("⌘"), .modifier("⇧"), .key("1-9")),
            ShortcutItem("Copy to clipboard", keys: .modifier("⌘"), .key("C"))
        ]),
        
        ShortcutCategory("Modes & Features", shortcuts: [
            ShortcutItem("Toggle search/prompt", keys: .modifier("⌘"), .key("F")),
            ShortcutItem("Toggle preview", keys: .modifier("⌥"), .special("Space")),
            ShortcutItem("Toggle dictation", keys: .modifier("⌥"), .key("D")),
            ShortcutItem("Enhance prompt", keys: .modifier("⌘"), .key("E"))
        ])
    ]
}
