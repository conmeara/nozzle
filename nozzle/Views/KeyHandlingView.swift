import Sauce
import SwiftUI
import Defaults

// Keyboard navigation throttler to prevent preview pane lag
@MainActor
private enum KeyboardNavigationThrottle {
  static let throttler = Throttler(minimumDelay: 0.05) // 50ms throttle for keyboard navigation
}

struct KeyHandlingView<Content: View>: View {
  @Binding var searchQuery: String
  @FocusState.Binding var searchFocused: Bool
  @Binding var currentTabPage: Int
  @Binding var showingShortcuts: Bool
  let totalPages: Int
  let onPreviousTab: () -> Void
  let onNextTab: () -> Void
  @ViewBuilder let content: () -> Content

  @Environment(AppState.self) private var appState
  @Environment(ContentManager.self) private var contentManager

  var body: some View {
    content()
      .onKeyPress { _ in
        // When inline rename is active anywhere, let focused controls (e.g., TextField/TextEditor)
        // handle keys like Enter/Escape without global interception.
        if contentManager.renameActiveItemId != nil {
          return .ignored
        }

        // Handle Cmd+Z for undo (check before text field processing)
        if let event = NSApp.currentEvent {
          let modifierFlags = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function])
          let isZCharacter = event.charactersIgnoringModifiers?.lowercased() == "z"
          let isZKeycode = event.keyCode == UInt16(Sauce.shared.keyCode(for: .z))
          let isZ = isZCharacter || isZKeycode

          if modifierFlags == .command && isZ {
            if searchFocused {
              if appState.canUndoInputEnhancement {
                appState.undoEnhancement()
                return .handled
              }
              return .ignored
            }
            if contentManager.isPromptEditorEditing {
              if appState.canUndoEditorEnhancement {
                appState.undoEnhancement()
                return .handled
              }
              return .ignored
            }
            if appState.canUndoEnhancement {
              appState.undoEnhancement()
              return .handled
            }
            // Let focused text inputs keep native undo/redo behavior when there is
            // no pending enhancement-specific undo state.
            // Check if we have a text field focused first - let text fields handle their own undo
            if !searchFocused && appState.undoManager.canUndo {
              appState.undoManager.undo()
              return .handled
            }
            // Let text fields handle their own undo
            return .ignored
          }
        }

        // Unfortunately, key presses don't allow access to
        // key code and don't properly work with multiple inputs,
        // so pressing ⌘, on non-English layout doesn't open
        // preferences. Stick to NSEvent to fix this behavior.
        // Keyboard handling is now done through the switch statement below
        
        // Check for plain Enter to immediately paste current item
        if let event = NSApp.currentEvent,
           (event.keyCode == UInt16(Key.return.QWERTYKeyCode) || event.keyCode == UInt16(Key.keypadEnter.QWERTYKeyCode)) {
          let modifierFlags = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function])
          
          if modifierFlags.isEmpty {
            // Check if dictation is active first
            if DictationManager.shared.isRecording {
              Task {
                await DictationManager.shared.stopDictation(saveTranscription: true)
              }
              return .handled
            }
            // Plain Enter - combined paste (swapped behavior)
            // Only handle if we have multiple selections or prompt text
            if !contentManager.selectedItems.isEmpty || !appState.promptText.isEmpty {
              appState.performCombinedPaste()
              return .handled
            }
            return .handled
          } else if modifierFlags == .command {
            _ = appState.performSingleItemPaste()
            return .handled
          } else if modifierFlags == .shift {
            // Shift+Enter in prompt mode - let TextEditor handle naturally for newlines
            if !appState.isSearchMode {
              return .ignored  // Let TextEditor handle the newline
            }
          }
        }
        
        // Robustly handle Command+Delete to clear selections, chips, and input
        if let event = NSApp.currentEvent {
          let modifierFlags = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function])
          let isDelete = event.keyCode == UInt16(Key.delete.QWERTYKeyCode)
            || Sauce.shared.key(for: Int(event.keyCode)) == .delete
          if modifierFlags == .command && isDelete {
            appState.clearSelectionAndPrompt()
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
        case .moveToNext:
          guard NSApp.characterPickerWindow == nil else {
            return .ignored
          }
          if contentManager.activeSourceId == "clipboard" {
            // Throttle clipboard navigation to prevent preview lag
            KeyboardNavigationThrottle.throttler.throttle {
              appState.highlightNext()
            }
          } else {
            appState.isKeyboardNavigating = true
            let items: [ContentItem]
            if contentManager.activeSourceId == "aggregated" {
              items = contentManager.selectedItems
            } else {
              items = contentManager.getItems(for: contentManager.activeSourceId).filter(\.isVisible)
            }
            if items.isEmpty { return .handled }
            
            // Throttle focus changes to prevent preview pane lag
            KeyboardNavigationThrottle.throttler.throttle {
              if let focused = contentManager.focusedItemId,
                 let idx = items.firstIndex(where: { $0.id == focused }),
                 idx + 1 < items.count {
                contentManager.focus(items[idx + 1].id)
              } else {
                contentManager.focus(items.first!.id)
              }
            }
          }
          return .handled
        case .moveToLast:
          guard NSApp.characterPickerWindow == nil else {
            return .ignored
          }
          if contentManager.activeSourceId == "clipboard" {
            // Throttle clipboard navigation to prevent preview lag
            KeyboardNavigationThrottle.throttler.throttle {
              appState.highlightLast()
            }
          } else {
            appState.isKeyboardNavigating = true
            let items: [ContentItem]
            if contentManager.activeSourceId == "aggregated" {
              items = contentManager.selectedItems
            } else {
              items = contentManager.getItems(for: contentManager.activeSourceId).filter(\.isVisible)
            }
            
            // Throttle focus changes to prevent preview pane lag
            KeyboardNavigationThrottle.throttler.throttle {
              if let last = items.last { contentManager.focus(last.id) }
            }
          }
          return .handled
        case .moveToPrevious:
          guard NSApp.characterPickerWindow == nil else {
            return .ignored
          }
          if contentManager.activeSourceId == "clipboard" {
            // Throttle clipboard navigation to prevent preview lag
            KeyboardNavigationThrottle.throttler.throttle {
              appState.highlightPrevious()
            }
          } else {
            appState.isKeyboardNavigating = true
            let items: [ContentItem]
            if contentManager.activeSourceId == "aggregated" {
              items = contentManager.selectedItems
            } else {
              items = contentManager.getItems(for: contentManager.activeSourceId).filter(\.isVisible)
            }
            if items.isEmpty { return .handled }
            
            // Throttle focus changes to prevent preview pane lag
            KeyboardNavigationThrottle.throttler.throttle {
              if let focused = contentManager.focusedItemId,
                 let idx = items.firstIndex(where: { $0.id == focused }),
                 idx - 1 >= 0 {
                contentManager.focus(items[idx - 1].id)
              } else {
                contentManager.focus(items.last!.id)
              }
            }
          }
          return .handled
        case .moveToFirst:
          guard NSApp.characterPickerWindow == nil else {
            return .ignored
          }
          if contentManager.activeSourceId == "clipboard" {
            // Throttle clipboard navigation to prevent preview lag
            KeyboardNavigationThrottle.throttler.throttle {
              appState.highlightFirst()
            }
          } else {
            appState.isKeyboardNavigating = true
            let items: [ContentItem]
            if contentManager.activeSourceId == "aggregated" {
              items = contentManager.selectedItems
            } else {
              items = contentManager.getItems(for: contentManager.activeSourceId).filter(\.isVisible)
            }
            
            // Throttle focus changes to prevent preview pane lag
            KeyboardNavigationThrottle.throttler.throttle {
              if let first = items.first { contentManager.focus(first.id) }
            }
          }
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
          // First check if shortcuts panel is showing - close it instead of the main popup
          if showingShortcuts {
            withAnimation(.easeInOut(duration: 0.2)) {
              showingShortcuts = false
            }
            return .handled
          }
          // Then check if dictation is recording - if so, cancel it instead of closing
          if DictationManager.shared.isRecording {
            Task {
              await DictationManager.shared.cancelDictation()
            }
            return .handled
          }
          // Otherwise close the app as normal
          appState.popup.close()
          return .handled
        case .togglePreview:
          appState.togglePreview()
          return .handled
        case .togglePromptMode:
          appState.isSearchMode.toggle()
          appState.isPromptMode = !appState.isSearchMode  // Ensure they're opposite
          // Use a small delay to ensure the new input field is rendered before focusing
          Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            searchFocused = true
          }
          return .handled
        case .toggleDictation:
          Task {
            let binding = appState.isSearchMode ? 
              Binding(get: { appState.history.searchQuery }, set: { appState.history.searchQuery = $0 }) :
              Binding(get: { appState.promptText }, set: { appState.promptText = $0 })
            await DictationManager.shared.toggleDictation(for: binding)
          }
          return .handled
        case .enhancePrompt:
          // Enhance prompt if not in search mode
          if !appState.isSearchMode {
            appState.performEnhancePrompt()
          }
          return .handled
        case .showShortcuts:
          // Toggle keyboard shortcuts panel
          withAnimation(.easeInOut(duration: 0.2)) {
            showingShortcuts.toggle()
          }
          return .handled
        case .openPrompts:
          // Toggle prompts tab - open if not active, close if active
          if contentManager.activeSourceId == "prompts" {
            // Already in prompts, return to previous tab
            contentManager.activeSourceId = contentManager.lastNonPromptsSourceId
          } else {
            // Not in prompts, open prompts and save current tab
            contentManager.lastNonPromptsSourceId = contentManager.activeSourceId
            contentManager.activeSourceId = "prompts"
          }
          return .handled
        case .toggleSelection:
          // Special behavior for prompts tab - add as chip and return to previous tab
          if contentManager.activeSourceId == "prompts",
             let focusedItem = contentManager.focusedContentItem,
             let url = focusedItem.fileURL {
            // Add as prompt chip
            appState.addPromptChip(url: url)
            // Return to previous tab
            contentManager.activeSourceId = contentManager.lastNonPromptsSourceId
            return .handled
          }
          // Default tab behavior for other sources
          if contentManager.activeSourceId == "clipboard" {
            if let item = appState.history.selectedItem {
              contentManager.toggleSelection(item.id)
              appState.updateFooterItemVisibility()
            }
          } else if let focusedItem = contentManager.focusedContentItem {
            contentManager.toggleSelection(focusedItem.id)
            appState.updateFooterItemVisibility()
          }
          return .handled
        case .previousTab:
          onPreviousTab()
          return .handled
        case .nextTab:
          onNextTab()
          return .handled
        case .previousTabPage:
          // Cmd+Shift+[ - navigate to previous tab page
          if currentTabPage > 0 {
            withAnimation(.easeInOut(duration: 0.2)) {
              currentTabPage -= 1
            }
          }
          return .handled
        case .nextTabPage:
          // Cmd+Shift+] - navigate to next tab page
          if currentTabPage < totalPages - 1 {
            withAnimation(.easeInOut(duration: 0.2)) {
              currentTabPage += 1
            }
          }
          return .handled
        case .refresh:
          // Cmd+R (or Cmd+Shift+R) - refresh current source
          if let activeSource = contentManager.sources[contentManager.activeSourceId] {
            Task {
              await activeSource.refresh()
            }
          }
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
          contentManager.toggleSelection(item.id)
          appState.selection = item.id
          contentManager.focus(item.id)
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
          contentManager.focus(item.id)
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
          contentManager.focus(item.id)
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
