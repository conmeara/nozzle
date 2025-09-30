import Defaults
import SwiftUI
import KeyboardShortcuts

struct HistoryItemView: View {
  @Bindable var item: HistoryItemDecorator

  @Environment(AppState.self) private var appState
  @Environment(ContentManager.self) private var contentManager
  @State private var copyButtonArea = CGRect.zero

  private func copyItemToClipboard() {
    // Copy the item directly to avoid triggering clipboard monitoring
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    
    // Copy the item's contents to clipboard
    let contents = item.item.contents
    for content in contents {
      guard content.type != NSPasteboard.PasteboardType.fileURL.rawValue else { continue }
      pasteboard.setData(content.value, forType: NSPasteboard.PasteboardType(content.type))
    }
    
    // Handle file URLs separately (same as Clipboard.copy logic)
    let fileURLItems: [NSPasteboardItem] = contents.compactMap { item in
      guard item.type == NSPasteboard.PasteboardType.fileURL.rawValue else { return nil }
      guard let value = item.value else { return nil }
      let pasteItem = NSPasteboardItem()
      pasteItem.setData(value, forType: NSPasteboard.PasteboardType(item.type))
      return pasteItem
    }
    pasteboard.writeObjects(fileURLItems)
    
    // Update clipboard sync and change count to prevent re-detection
    Clipboard.shared.changeCount = pasteboard.changeCount
    
    // Update item metadata
    item.item.lastCopiedAt = Date.now
    item.item.numberOfCopies += 1
    
    // Add to delayed reorder queue
    appState.history.addToDelayedReorder(item.item)
  }

  var body: some View {
    ListItemView(
      id: item.id,
      appIcon: item.appIcon,
      image: item.image,
      accessoryImage: item.accessoryImage,
      attributedTitle: item.attributedTitle,
      shortcuts: item.shortcuts,
      isSelected: item.isSelected,
      selectionSymbol: (contentManager.isExample(item.id) ? "pencil.circle.fill" : "checkmark.circle.fill"),
      selectionSymbolColor: .white,
      selectionBackgroundColor: (contentManager.isExample(item.id) ? .yellow : nil)
    ) {
      Text(verbatim: item.title)
    }
    .background(
      GeometryReader { geometry in
        Color.clear
          .onAppear {
            copyButtonArea = geometry.frame(in: .local)
          }
          .onChange(of: geometry.size) { _, newSize in
            copyButtonArea = CGRect(origin: .zero, size: newSize)
          }
      }
    )
    .onMouseMove {
      // Mouse movement turns off keyboard navigation so pointer clicks drive focus
      appState.isKeyboardNavigating = false
    }
    .onTapGesture { location in
      appState.isKeyboardNavigating = false
      let clickCount = NSApp.currentEvent?.clickCount ?? 0

      // Handle double-click first
      if clickCount >= 2 {
        contentManager.focus(item.id)
        appState.selection = item.id
        contentManager.toggleSelection(item.id)
        item.isSelected = contentManager.isSelected(item.id)
        appState.updateFooterItemVisibility()
        return
      }

      // Handle modifier keys before checking click location
      if NSEvent.modifierFlags.contains(.option) {
        // Option-click: toggle between unselected and example (skip context state)
        if contentManager.isExample(item.id) {
          // Currently example → deselect completely
          contentManager.toggleExample(item.id)
          contentManager.toggleSelection(item.id)
          item.isSelected = false
        } else if item.isSelected {
          // Currently context → switch to example
          contentManager.toggleExample(item.id)
        } else {
          // Currently unselected → select and mark as example
          contentManager.toggleSelection(item.id)
          item.isSelected = true
          contentManager.toggleExample(item.id)
        }
        appState.updateFooterItemVisibility()
        contentManager.focus(item.id)
        return
      }

      if NSEvent.modifierFlags.contains(.command) {
        // Command-click anywhere: immediate paste
        appState.history.select(item)
        contentManager.focus(item.id)
        return
      }

      // Check if click is in the selection area (right 42 pixels)
      let frameWidth = copyButtonArea.width > 0 ? copyButtonArea.width : 300
      let selectionAreaWidth: CGFloat = 42
      let isSelectionAreaClick = location.x > (frameWidth - selectionAreaWidth)

      if isSelectionAreaClick {
        // Toggle selection on/off (also clears example state if deselecting)
        if item.isSelected && contentManager.isExample(item.id) {
          contentManager.toggleExample(item.id)
        }
        contentManager.toggleSelection(item.id)
        item.isSelected = contentManager.isSelected(item.id)
        appState.updateFooterItemVisibility()
        contentManager.focus(item.id)
      } else {
        // Regular click: focus preview without changing selection
        appState.selection = item.id
        contentManager.focus(item.id)
      }
    }
    .contextMenu {
      Button("Copy") {
        copyItemToClipboard()
      }
      
      Button(item.isPinned ? "Unpin" : "Pin") {
        appState.history.togglePin(item)
      }
      .keyboardShortcut(
        KeyEquivalent("p"),
        modifiers: KeyboardShortcuts.Shortcut(name: .pin)?.toEventModifiers() ?? [.option]
      )
      
      Button("Delete") {
        appState.highlightNext()
        appState.history.delete(item)
      }
      .keyboardShortcut(
        .backspace,
        modifiers: KeyboardShortcuts.Shortcut(name: .delete)?.toEventModifiers() ?? [.option]
      )
      
      Divider()
      
      // Put Context above Example
      Button(contentManager.isSelected(item.id) ? "Remove as Context" : "Mark as Context") {
        contentManager.toggleSelection(item.id)
        item.isSelected = contentManager.isSelected(item.id)
        appState.updateFooterItemVisibility()
      }
      .keyboardShortcut(.tab)

      Button(contentManager.isExample(item.id) ? "Remove as Example" : "Mark as Example") {
        contentManager.toggleExample(item.id)
      }
    }
  }
}
