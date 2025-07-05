import Sauce
import SwiftUI

struct KeyHandlingView<Content: View>: View {
  @Binding var searchQuery: String
  @FocusState.Binding var searchFocused: Bool
  @ViewBuilder let content: () -> Content

  @Environment(AppState.self) private var appState

  var body: some View {
    content()
      .onKeyPress { _ in
        // Unfortunately, key presses don't allow access to
        // key code and don't properly work with multiple inputs,
        // so pressing ⌘, on non-English layout doesn't open
        // preferences. Stick to NSEvent to fix this behavior.
        // Keyboard handling is now done through the switch statement below
        
        // Check for plain Enter to toggle selection
        if let event = NSApp.currentEvent,
           (event.keyCode == UInt16(Key.return.QWERTYKeyCode) || event.keyCode == UInt16(Key.keypadEnter.QWERTYKeyCode)) {
          let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.capsLock)
          
          if modifierFlags.isEmpty {
            // Plain Enter - toggle selection
            if let item = appState.history.selectedItem {
              item.isSelected.toggle()
              appState.updateFooterItemVisibility()
            }
            return .handled
          } else if modifierFlags == [.command, .shift] {
            // Command-Shift-Enter - paste just the focused item
            if let item = appState.history.selectedItem {
              appState.popup.close()
              Clipboard.shared.copy(item.item)
              Clipboard.shared.paste()
            }
            return .handled
          } else if modifierFlags == .command {
            // Command-Enter (combined paste)
            // Only handle if we have multiple selections or prompt text
            if !appState.history.selectedItems.isEmpty || !appState.promptText.isEmpty {
              appState.performCombinedPaste()
              return .handled
            }
          }
        }
        
        switch KeyChord(NSApp.currentEvent) {
        case .clearSelection:
          appState.clearSelectionAndPrompt()
          return .handled
        case .clearHistory:
          if let item = appState.footer.items.first(where: { $0.title == "clear" }),
             item.confirmation != nil,
             let suppressConfirmation = item.suppressConfirmation {
            if suppressConfirmation.wrappedValue {
              item.action()
            } else {
              item.showConfirmation = true
            }
            return .handled
          } else {
            return .ignored
          }
        case .clearHistoryAll:
          // No longer used
          return .ignored
        case .clearSearch:
          searchQuery = ""
          return .handled
        case .deleteCurrentItem:
          if let item = appState.history.selectedItem {
            appState.highlightNext()
            appState.history.delete(item)
          }
          return .handled
        case .deleteOneCharFromSearch:
          searchFocused = true
          _ = searchQuery.popLast()
          return .handled
        case .deleteLastWordFromSearch:
          searchFocused = true
          let newQuery = searchQuery.split(separator: " ").dropLast().joined(separator: " ")
          if newQuery.isEmpty {
            searchQuery = ""
          } else {
            searchQuery = "\(newQuery) "
          }

          return .handled
        case .moveToNext:
          guard NSApp.characterPickerWindow == nil else {
            return .ignored
          }

          appState.highlightNext()
          return .handled
        case .moveToLast:
          guard NSApp.characterPickerWindow == nil else {
            return .ignored
          }

          appState.highlightLast()
          return .handled
        case .moveToPrevious:
          guard NSApp.characterPickerWindow == nil else {
            return .ignored
          }

          appState.highlightPrevious()
          return .handled
        case .moveToFirst:
          guard NSApp.characterPickerWindow == nil else {
            return .ignored
          }

          appState.highlightFirst()
          return .handled
        case .openPreferences:
          appState.openPreferences()
          return .handled
        case .pinOrUnpin:
          appState.history.togglePin(appState.history.selectedItem)
          return .handled
        case .selectCurrentItem:
          // This now only triggers for Enter with modifiers we didn't handle above
          // (like Option+Enter for paste)
          appState.select()
          return .handled
        case .close:
          appState.popup.close()
          return .handled
        case .togglePreview:
          appState.togglePreview()
          return .handled
        case .togglePromptMode:
          appState.isSearchMode.toggle()
          appState.isPromptMode = !appState.isSearchMode  // Ensure they're opposite
          searchFocused = true
          return .handled
        default:
          ()
        }

        // Check for Command+Number to toggle selection
        if let event = NSApp.currentEvent,
           event.modifierFlags.contains(.command),
           !event.modifierFlags.contains(.shift),
           let key = Sauce.shared.key(for: Int(event.keyCode)),
           let item = appState.history.items.first(where: { $0.shortcuts.contains(where: { $0.key == key }) }) {
          // Toggle the item's selection
          item.isSelected.toggle()
          appState.selection = item.id
          appState.updateFooterItemVisibility()
          return .handled
        }
        
        // Check for Command+Shift+Number to paste just that item
        if let event = NSApp.currentEvent,
           event.modifierFlags.contains(.command),
           event.modifierFlags.contains(.shift),
           let key = Sauce.shared.key(for: Int(event.keyCode)),
           let item = appState.history.items.first(where: { $0.shortcuts.contains(where: { $0.key == key }) }) {
          // Paste this specific item
          appState.selection = item.id
          appState.popup.close()
          Clipboard.shared.copy(item.item)
          Clipboard.shared.paste()
          
          // Only call this in the App Store version.
          AppStoreReview.ask()
          return .handled
        }
        
        // Original logic for other modifier combinations
        if let item = appState.history.pressedShortcutItem {
          appState.selection = item.id
          Task {
            try? await Task.sleep(for: .milliseconds(50))
            appState.history.select(item)
          }
          return .handled
        }

        return .ignored
      }
  }
}
