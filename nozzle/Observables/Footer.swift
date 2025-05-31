import Defaults
import SwiftUI

@Observable
class Footer {
  var items: [FooterItem] = []

  var selectedItem: FooterItem? {
    willSet {
      selectedItem?.isSelected = false
      newValue?.isSelected = true
    }
  }

  var suppressClearAlert = Binding<Bool>(
    get: { Defaults[.suppressClearAlert] },
    set: { Defaults[.suppressClearAlert] = $0 }
  )

  init() { // swiftlint:disable:this function_body_length
    items = [
      FooterItem(
        title: "paste_combined",
        shortcuts: [KeyShortcut(key: .v)],
        help: "paste_combined_tooltip"
      ) {
        Task { @MainActor in
          AppState.shared.performCombinedPaste()
        }
      },
      FooterItem(
        title: "copy_combined",
        shortcuts: [KeyShortcut(key: .return)],
        help: "copy_combined_tooltip"
      ) {
        Task { @MainActor in
          AppState.shared.performCombinedCopy()
        }
      },
      FooterItem(
        title: "clear_selection",
        shortcuts: [KeyShortcut(key: .delete, modifierFlags: [.command])],
        help: "clear_selection_tooltip"
      ) {
        Task { @MainActor in
          AppState.shared.clearSelectionAndPrompt()
        }
      },
      FooterItem(
        title: "preferences",
        shortcuts: [KeyShortcut(key: .comma)]
      ) {
        Task { @MainActor in
          AppState.shared.openPreferences()
        }
      },
      FooterItem(
        title: "about",
        help: "about_tooltip"
      ) {
        AppState.shared.openAbout()
      },
      FooterItem(
        title: "quit",
        shortcuts: [KeyShortcut(key: .q)],
        help: "quit_tooltip"
      ) {
        AppState.shared.quit()
      }
    ]
  }
}
