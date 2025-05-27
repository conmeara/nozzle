import Defaults
import SwiftUI

struct HistoryItemView: View {
  @Bindable var item: HistoryItemDecorator

  @Environment(AppState.self) private var appState

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
    .onTapGesture {
      if NSEvent.modifierFlags.contains(.command) {
        // Command-click: immediate paste
        appState.history.select(item)
      } else {
        // Regular click: toggle selection
        item.isSelected.toggle()
        appState.selection = item.id  // Move focus to this item
      }
    }
    .popover(isPresented: $item.showPreview, arrowEdge: .trailing) {
      PreviewItemView(item: item)
    }
  }
}
