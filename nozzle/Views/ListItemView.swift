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
  var selectionSymbol: String = "checkmark.circle.fill"
  var selectionSymbolColor: Color = .white
  var selectionBackgroundColor: Color? = nil
  var onCopyAction: (() -> Void)? = nil
  @ViewBuilder var title: () -> Title

  @Default(.showApplicationIcons) private var showIcons
  @Environment(AppState.self) private var appState
  @Environment(ContentManager.self) private var contentManager
  @Environment(ModifierFlags.self) private var modifierFlags
  @State private var isHovering = false
  @State private var showCopiedFeedback = false
  
  private func triggerCopyFeedback() {
    // Visual feedback
    withAnimation(.easeInOut(duration: 0.2)) {
      showCopiedFeedback = true
    }
    
    // Audio feedback
    if let sound = NSSound(named: "Write") {
      sound.play()
    }
    
    // Reset after delay
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
      withAnimation(.easeInOut(duration: 0.3)) {
        showCopiedFeedback = false
      }
    }
  }
  
  private enum HighlightState {
    case none
    case hover
    case preview
  }

  private var highlightState: HighlightState {
    // Freeze to the renaming item as active; suppress hover background for others
    if let activeRename = contentManager.renameActiveItemId, activeRename != id {
      return .none
    }

    // Determine whether this row is the current preview target
    let isPreviewed = (appState.history.selectedItem?.id == id ||
                       appState.footer.selectedItem?.id == id ||
                       contentManager.focusedItemId == id)

    // During keyboard navigation, always show the previewed row
    if appState.isKeyboardNavigating {
      return isPreviewed ? .preview : .none
    }

    if isHovering {
      return isPreviewed ? .preview : .hover
    }

    if let hoveredId = appState.hoveredListItemId, hoveredId == id {
      return isPreviewed ? .preview : .hover
    }

    return isPreviewed ? .preview : .none
  }

  private var hoverBackgroundOpacity: Double {
    switch highlightState {
    case .preview: return 0.6
    case .hover: return 0.3
    case .none: return 0
    }
  }

  private var selectedBackgroundOpacity: Double {
    switch highlightState {
    case .preview: return 0.5
    case .hover: return 0.25
    case .none: return 0.2
    }
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
        .padding(.leading, 6)
        .padding(.vertical, 5)
      }

      Spacer()
        .frame(width: (showIcons && appIcon != nil) ? 6 : 12)

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
        // When showing a thumbnail instead of text, use a spacer to push actions right
        Spacer()
      } else {
        ListItemTitleView(attributedTitle: attributedTitle, title: title)
          .padding(.trailing, 1)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      // Copy button, checkbox, or Command shortcut
      if showCheckbox {
        ZStack {
          if modifierFlags.flags.contains(.command) && !shortcuts.isEmpty {
            // Show shortcut when Command is held (replaces checkmark)
            ForEach(shortcuts) { shortcut in
              KeyboardShortcutView(shortcut: shortcut)
                .opacity(shortcut.isVisible(shortcuts, modifierFlags.flags) ? 1 : 0)
            }
            .padding(.trailing, 20)
            .frame(maxWidth: .infinity, alignment: .trailing)
          } else if isSelected {
            // Show round checkbox when item is selected
            Image(systemName: selectionSymbol)
              .font(.system(size: 14))
              .foregroundColor(selectionSymbolColor)
              .opacity(0.8)
              .frame(maxWidth: .infinity, alignment: .trailing)
          } else if isHovering {
            // Show copy button when hovering, or checkmark when copied
            if showCopiedFeedback {
              Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.green)
                .opacity(0.8)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .transition(.scale.combined(with: .opacity))
            } else {
              Image(systemName: "doc.on.doc")
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .opacity(0.6)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .transition(.scale.combined(with: .opacity))
                .onTapGesture {
                  onCopyAction?()
                  triggerCopyFeedback()
                }
            }
          }
        }
        .frame(width: 30)
        .padding(.trailing, 8)
      } else if !shortcuts.isEmpty {
        // For footer items, just show shortcuts
        ZStack {
          ForEach(shortcuts) { shortcut in
            KeyboardShortcutView(shortcut: shortcut)
              .opacity(shortcut.isVisible(shortcuts, modifierFlags.flags) ? 1 : 0)
          }
        }
        .frame(width: 30)
        .padding(.trailing, 8)
      } else {
        Spacer()
          .frame(width: 30)
          .padding(.trailing, 8)
      }
    }
    .frame(minHeight: 22)
    .id(id)
    .frame(maxWidth: .infinity, alignment: .leading)
    .foregroundStyle(.primary)
    .background {
      // Selection and hover/focus states
      if isSelected {
        let base = (selectionBackgroundColor ?? Color(NSColor.controlAccentColor))
        base.opacity(selectedBackgroundOpacity)
      } else if hoverBackgroundOpacity > 0 {
        Color(NSColor.quaternaryLabelColor).opacity(hoverBackgroundOpacity)
      } else {
        Color.clear
      }
    }
    .clipShape(.rect(cornerRadius: DesignConstants.cornerRadius))
    .padding(.leading, 3)
    .padding(.trailing, 5)
    // Any mouse movement exits keyboard navigation mode
    .onMouseMove {
      appState.isKeyboardNavigating = false
    }
    .onHover { hovering in
      // During inline rename, freeze hover-driven hover state changes
      guard contentManager.renameActiveItemId == nil else { return }

      isHovering = hovering

      if hovering {
        // Track this row as globally hovered for consistent highlighting
        appState.hoveredListItemId = id
      } else if appState.hoveredListItemId == id {
        // Clear global hover state if this was the hovered item
        appState.hoveredListItemId = nil
      }
    }
    .help(help ?? "")
  }
}
