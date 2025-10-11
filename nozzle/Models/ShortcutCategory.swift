import Foundation
import KeyboardShortcuts

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

/// Shortcut type - either customizable through settings or fixed
enum ShortcutType: Hashable {
    case customizable(KeyboardShortcuts.Name)
    case fixed([KeyComponent])
}

/// Individual shortcut item
struct ShortcutItem: Identifiable, Hashable {
    let id = UUID()
    let description: String
    private let type: ShortcutType
    
    init(_ description: String, customizable shortcutName: KeyboardShortcuts.Name) {
        self.description = description
        self.type = .customizable(shortcutName)
    }
    
    init(_ description: String, fixed keys: KeyComponent...) {
        self.description = description
        self.type = .fixed(Array(keys))
    }
    
    /// Gets the current keys for this shortcut (either actual customized or default)
    var keys: [KeyComponent] {
        switch type {
        case .customizable(let name):
            return getCustomizableKeys(for: name)
        case .fixed(let keys):
            return keys
        }
    }
    
    /// Whether this shortcut can be customized
    var isCustomizable: Bool {
        if case .customizable = type { return true }
        return false
    }
    
    /// The keyboard shortcut name if customizable
    var shortcutName: KeyboardShortcuts.Name? {
        if case .customizable(let name) = type { return name }
        return nil
    }
    
    /// Converts a KeyboardShortcuts.Shortcut to KeyComponent array
    private func getCustomizableKeys(for name: KeyboardShortcuts.Name) -> [KeyComponent] {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: name) else {
            // Fallback to default from the name definition
            return getDefaultKeys(for: name)
        }
        
        var components: [KeyComponent] = []
        
        // Add modifiers
        if shortcut.modifiers.contains(.command) { components.append(.modifier("⌘")) }
        if shortcut.modifiers.contains(.option) { components.append(.modifier("⌥")) }
        if shortcut.modifiers.contains(.control) { components.append(.modifier("⌃")) }
        if shortcut.modifiers.contains(.shift) { components.append(.modifier("⇧")) }
        
        // Add the key
        if let key = shortcut.key {
            let keyString = getKeyString(for: key)
            if keyString.count == 1 {
                components.append(.key(keyString))
            } else {
                components.append(.special(keyString))
            }
        }
        
        return components
    }
    
    /// Gets default keys for a shortcut name
    private func getDefaultKeys(for name: KeyboardShortcuts.Name) -> [KeyComponent] {
        switch name {
        case .popup: return [.modifier("⌥"), .key("V")]
        case .pin: return [.modifier("⌥"), .key("P")]
        case .delete: return [.modifier("⌥"), .special("⌫")]
        case .togglePreview: return [.modifier("⌃"), .special("Space")]
        case .clearSelection: return [.modifier("⌘"), .special("⌫")]
        case .togglePromptMode: return [.modifier("⌘"), .key("F")]
        case .toggleDictation: return [.modifier("⌥"), .key("D")]
        case .enhancePrompt: return [.modifier("⌘"), .key("E")]
        case .showShortcuts: return [.modifier("⌘"), .key("/")]
        case .openPrompts: return [.modifier("⌘"), .key("P")]
        case .sendFeedback: return [.modifier("⌥"), .key("F")]
        default: return [.key("?")]
        }
    }
    
    /// Converts KeyboardShortcuts.Key to string representation
    private func getKeyString(for key: KeyboardShortcuts.Key) -> String {
        switch key {
        case .a: return "A"
        case .b: return "B"
        case .c: return "C"
        case .d: return "D"
        case .e: return "E"
        case .f: return "F"
        case .g: return "G"
        case .h: return "H"
        case .i: return "I"
        case .j: return "J"
        case .k: return "K"
        case .l: return "L"
        case .m: return "M"
        case .n: return "N"
        case .o: return "O"
        case .p: return "P"
        case .q: return "Q"
        case .r: return "R"
        case .s: return "S"
        case .t: return "T"
        case .u: return "U"
        case .v: return "V"
        case .w: return "W"
        case .x: return "X"
        case .y: return "Y"
        case .z: return "Z"
        case .zero: return "0"
        case .one: return "1"
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        case .space: return "Space"
        case .delete: return "⌫"
        case .return: return "⏎"
        case .escape: return "Esc"
        case .upArrow: return "↑"
        case .downArrow: return "↓"
        case .leftArrow: return "←"
        case .rightArrow: return "→"
        case .slash: return "/"
        case .comma: return ","
        case .period: return "."
        case .semicolon: return ";"
        case .quote: return "'"
        case .leftBracket: return "["
        case .rightBracket: return "]"
        case .tab: return "Tab"
        default: return "?"
        }
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
            ShortcutItem("Open nozzle", customizable: .popup),
            ShortcutItem("Close popup", fixed: .special("Esc")),
            ShortcutItem("Open preferences", fixed: .modifier("⌘"), .key(",")),
            ShortcutItem("Show keyboard shortcuts", customizable: .showShortcuts),
            ShortcutItem("Send feedback", customizable: .sendFeedback),
            ShortcutItem("Open prompts", customizable: .openPrompts)
        ]),
        
        ShortcutCategory("Paste Operations", shortcuts: [
            ShortcutItem("Paste combined", fixed: .special("⏎")),
            ShortcutItem("Paste single item", fixed: .modifier("⌘"), .special("⏎")),
            ShortcutItem("Paste numbered", fixed: .modifier("⌘"), .modifier("⇧"), .key("1-9")),
            ShortcutItem("Copy to clipboard", fixed: .modifier("⌘"), .key("C"))
        ]),
        
        ShortcutCategory("Selection & Management", shortcuts: [
            ShortcutItem("Toggle selection", fixed: .special("Tab")),
            ShortcutItem("Select numbered", fixed: .modifier("⌘"), .key("1-9")),
            ShortcutItem("Clear selection", customizable: .clearSelection),
            ShortcutItem("Pin/Unpin item", customizable: .pin),
            ShortcutItem("Delete item", customizable: .delete)
        ]),
        
        ShortcutCategory("Modes & Features", shortcuts: [
            ShortcutItem("Toggle search/prompt", customizable: .togglePromptMode),
            ShortcutItem("Toggle preview", customizable: .togglePreview),
            ShortcutItem("Toggle dictation", customizable: .toggleDictation),
            ShortcutItem("Enhance prompt", customizable: .enhancePrompt)
        ]),
        
        ShortcutCategory("Navigation", shortcuts: [
            ShortcutItem("Move up", fixed: .special("↑")),
            ShortcutItem("Move down", fixed: .special("↓")),
            ShortcutItem("Move to first", fixed: .modifier("⌘"), .special("↑")),
            ShortcutItem("Move to last", fixed: .modifier("⌘"), .special("↓")),
            ShortcutItem("Previous tab", fixed: .modifier("⌘"), .key("[")),
            ShortcutItem("Next tab", fixed: .modifier("⌘"), .key("]")),
            ShortcutItem("Previous tab page", fixed: .modifier("⌘"), .modifier("⇧"), .key("[")),
            ShortcutItem("Next tab page", fixed: .modifier("⌘"), .modifier("⇧"), .key("]"))
        ])
    ]
}
