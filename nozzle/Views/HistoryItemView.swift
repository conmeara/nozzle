import Defaults
import SwiftUI

struct HistoryItemView: View {
  @Bindable var item: HistoryItemDecorator

  @Environment(AppState.self) private var appState
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
      appIcon: item.applicationImage,
      image: item.thumbnailImage,
      accessoryImage: item.thumbnailImage != nil ? nil : ColorImage.from(item.title),
      attributedTitle: item.attributedTitle,
      shortcuts: item.shortcuts,
      isSelected: item.isSelected
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
      // Update focus to this item on hover
      appState.isKeyboardNavigating = false
      appState.selection = item.id
    }
    .onTapGesture { location in
      // Check if click is in the copy button area (right 60 pixels)
      let frameWidth = copyButtonArea.width > 0 ? copyButtonArea.width : 300 // fallback width
      let copyButtonAreaWidth: CGFloat = 60
      let isCopyButtonClick = location.x > (frameWidth - copyButtonAreaWidth)
      
      if isCopyButtonClick && !item.isSelected && !NSEvent.modifierFlags.contains(.command) {
        // Copy button clicked
        copyItemToClipboard()
      } else if NSEvent.modifierFlags.contains(.command) {
        // Command-click: immediate paste
        appState.history.select(item)
      } else {
        // Regular click: toggle selection
        item.isSelected.toggle()
        appState.selection = item.id  // Move focus to this item
        appState.updateFooterItemVisibility()
      }
    }
    .popover(isPresented: $item.showPreview, arrowEdge: .trailing) {
      PreviewItemView(item: item)
    }
  }
}
