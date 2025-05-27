import Defaults
import SwiftUI

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
  @ViewBuilder var title: () -> Title

  @Default(.showApplicationIcons) private var showIcons
  @Environment(AppState.self) private var appState
  @Environment(ModifierFlags.self) private var modifierFlags

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

      // Checkbox or Command shortcut
      if showCheckbox {
        ZStack {
          if modifierFlags.flags.contains(.command) && !shortcuts.isEmpty {
            // Show shortcut when Command is held
            ForEach(shortcuts) { shortcut in
              KeyboardShortcutView(shortcut: shortcut)
                .opacity(shortcut.isVisible(shortcuts, modifierFlags.flags) ? 1 : 0)
            }
          } else {
            // Show checkbox when Command is not held
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
              .font(.system(size: 14))
              .foregroundColor(isSelected ? .white : .primary)
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
    .foregroundStyle(isSelected ? Color.white : .primary)
    .background(
      isSelected 
        ? Color.accentColor.opacity(0.8)  // Blue for checked items
        : (appState.selection == id ? Color.gray.opacity(0.2) : .clear)  // Gray for focused, clear otherwise
    )
    .clipShape(.rect(cornerRadius: 4))
    .onHover { hovering in
      if hovering {
        if !appState.isKeyboardNavigating {
          appState.selectWithoutScrolling(id)
        } else {
          appState.hoverSelectionWhileKeyboardNavigating = id
        }
      }
    }
    .help(help ?? "")
  }
}
