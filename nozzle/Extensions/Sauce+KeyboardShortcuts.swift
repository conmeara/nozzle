import KeyboardShortcuts
import Sauce
import SwiftUI
import AppKit

extension Sauce {
  func key(shortcut: KeyboardShortcuts.Name) -> Key? {
    if let shortcut = KeyboardShortcuts.Shortcut(name: shortcut) {
      return Sauce.shared.key(for: shortcut.carbonKeyCode)
    } else {
      return nil
    }
  }
}

// Map a KeyboardShortcuts.Shortcut to SwiftUI EventModifiers for use in .keyboardShortcut
extension KeyboardShortcuts.Shortcut {
  func toEventModifiers() -> EventModifiers {
    var mods: EventModifiers = []
    if modifiers.contains(.command) { mods.insert(.command) }
    if modifiers.contains(.option) { mods.insert(.option) }
    if modifiers.contains(.control) { mods.insert(.control) }
    if modifiers.contains(.shift) { mods.insert(.shift) }
    return mods
  }
}
