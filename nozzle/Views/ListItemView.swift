import Defaults
import SwiftUI

// Shared hover throttler for clipboard hover selection (avoid static stored properties on generic types)
@MainActor
private enum ListItemHoverSelect {
  static let throttler = Throttler(minimumDelay: 0.2)
}

struct ListItemView<Title: View>: View {
  var id: UUID
  var appIcon: ApplicationImage?
  var image: NSImage?
  var accessoryImage: NSImage?
  var attributedTitle: AttributedString?
  var shortcuts: [KeyShortcut]
  var isSelected: Bool
  var help: LocalizedStringKey?
  var showCheckbox: Bool = true
  var selectionSymbol: String = "checkmark.circle.fill"
  var selectionSymbolColor: Color = .white
  var selectionBackgroundColor: Color? = nil
  @ViewBuilder var title: () -> Title

  @Default(.showApplicationIcons) private var showIcons
  @Environment(AppState.self) private var appState
  @Environment(ContentManager.self) private var contentManager
  @Environment(ModifierFlags.self) private var modifierFlags
  @State private var isHovering = false
  
  private var shouldShowHoverBackground: Bool {
    // Immediate hover background only when not keyboard navigating
    if isHovering && !appState.isKeyboardNavigating { return true }

    // Determine global focus across clipboard and universal sources
    let clipboardFocused = (appState.history.selectedItem?.id == id ||
                            appState.footer.selectedItem?.id == id)
    let universalFocused = (contentManager.focusedItemId == id)
    let isFocused = clipboardFocused || universalFocused

    // During keyboard navigation, show focused row regardless of hover
    if appState.isKeyboardNavigating { return isFocused }

    // Mouse-driven: avoid ghost focus when hovering a different row
    if let hoveredId = appState.hoveredListItemId { return isFocused && hoveredId == id }
    return isFocused
  }

  var body: some View {
    HStack(spacing: 0) {
      if showIcons, let appIcon {
        VStack {
          Spacer(minLength: 0)
          Image(nsImage: appIcon.nsImage)
            .resizable()
            .frame(width: 15, height: 15)
          Spacer(minLength: 0)
        }
        .padding(.leading, 4)
        .padding(.vertical, 5)
      }

      Spacer()
        .frame(width: showIcons ? 5 : 10)

      if let accessoryImage {
        Image(nsImage: accessoryImage)
          .accessibilityIdentifier("copy-history-item")
          .padding(.trailing, 5)
          .padding(.vertical, 5)
      }

      if let image {
        Image(nsImage: image)
          .accessibilityIdentifier("copy-history-item")
          .padding(.trailing, 5)
          .padding(.vertical, 5)
      } else {
        ListItemTitleView(attributedTitle: attributedTitle, title: title)
          .padding(.trailing, 5)
      }

      Spacer()

      // Copy button, checkbox, or Command shortcut
      if showCheckbox {
        ZStack {
          if modifierFlags.flags.contains(.command) && !shortcuts.isEmpty {
            // Show shortcut when Command is held
            ForEach(shortcuts) { shortcut in
              KeyboardShortcutView(shortcut: shortcut)
                .opacity(shortcut.isVisible(shortcuts, modifierFlags.flags) ? 1 : 0)
            }
          } else if isSelected {
            // Show round checkbox when item is selected
            Image(systemName: selectionSymbol)
              .font(.system(size: 14))
              .foregroundColor(selectionSymbolColor)
              .opacity(0.8)
              .frame(maxWidth: .infinity, alignment: .trailing)
          } else if isHovering {
            // Show copy button when hovering - always show the clipboard icon
            Image(systemName: "doc.on.doc")
              .font(.system(size: 12))
              .foregroundColor(.primary)
              .opacity(0.6)
              .frame(maxWidth: .infinity, alignment: .trailing)
          }
        }
        .frame(width: 50)
        .padding(.trailing, 10)
      } else if !shortcuts.isEmpty {
        // For footer items, just show shortcuts
        ZStack {
          ForEach(shortcuts) { shortcut in
            KeyboardShortcutView(shortcut: shortcut)
              .opacity(shortcut.isVisible(shortcuts, modifierFlags.flags) ? 1 : 0)
          }
        }
        .frame(width: 50)
        .padding(.trailing, 10)
      } else {
        Spacer()
          .frame(width: 50)
          .padding(.trailing, 10)
      }
    }
    .frame(minHeight: 22)
    .id(id)
    .frame(maxWidth: .infinity, alignment: .leading)
    .foregroundStyle(.primary)
    .background {
      if isSelected {
        (selectionBackgroundColor ?? Color(NSColor.controlAccentColor)).opacity(0.25)  // Subtle accent color for selection
      } else if shouldShowHoverBackground {
        Color(NSColor.quaternaryLabelColor).opacity(0.5)  // Hover background
      } else {
        Color.clear
      }
    }
    .clipShape(.rect(cornerRadius: 4))
    // Any mouse movement exits keyboard navigation mode
    .onMouseMove {
      appState.isKeyboardNavigating = false
    }
    .onHover { hovering in
      isHovering = hovering
      // Track hovered row globally to coordinate background across rows
      if hovering {
        appState.hoveredListItemId = id
      } else if appState.hoveredListItemId == id {
        appState.hoveredListItemId = nil
      }
      if hovering {
        if !appState.isKeyboardNavigating {
          // When preview pane is visible, debounce hover selection to reduce UI churn
          if appState.showPreviewPane {
            ListItemHoverSelect.throttler.minimumDelay = Double(Defaults[.hoverPreviewDelay]) / 1000
            ListItemHoverSelect.throttler.throttle {
              appState.selectWithoutScrolling(id)
            }
          } else {
            appState.selectWithoutScrolling(id)
          }
        } else {
          appState.hoverSelectionWhileKeyboardNavigating = id
        }
      } else {
        // Cancel any pending hover selection when leaving
        ListItemHoverSelect.throttler.cancel()
      }
    }
    .help(help ?? "")
  }
}
