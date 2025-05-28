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
        // Check for Command-V (combined paste) before standard key chord handling
        if let event = NSApp.currentEvent,
           event.keyCode == UInt16(KeyChord.pasteKey.QWERTYKeyCode),
           event.modifierFlags.contains(.command) {
          // Only handle if we have multiple selections or prompt text
          if !appState.history.selectedItems.isEmpty || !appState.promptText.isEmpty {
            appState.performCombinedPaste()
            return .handled
          }
        }
        
        // Check for Command-Enter (combined copy)
        if let event = NSApp.currentEvent,
           (event.keyCode == UInt16(Key.return.QWERTYKeyCode) || event.keyCode == UInt16(Key.keypadEnter.QWERTYKeyCode)),
           event.modifierFlags.contains(.command) {
          // Only handle if we have multiple selections or prompt text
          if !appState.history.selectedItems.isEmpty || !appState.promptText.isEmpty {
            appState.performCombinedCopy()
            return .handled
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
          appState.select()
          return .handled
        case .close:
          appState.popup.close()
          return .handled
        case .togglePreview:
          appState.togglePreview()
          return .handled
        case .togglePromptMode:
          appState.isPromptMode.toggle()
          return .handled
        case .toggleSelection:
          if let item = appState.history.selectedItem {
            item.isSelected.toggle()
            appState.updateFooterItemVisibility()
          }
          return .handled
        default:
          ()
        }

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
