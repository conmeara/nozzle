import SwiftUI

struct UniversalItemView: View {
    @Bindable var item: UniversalItemDecorator
    @Environment(AppState.self) private var appState
    @Environment(ContentManager.self) private var contentManager
    
    var body: some View {
        ListItemView(
            id: item.id,
            appIcon: nil,                        // optional: resolve by UTType/app owner later
            image: nil,                          // optional: lightweight thumbs in Phase 2
            accessoryImage: nil,
            attributedTitle: nil,
            shortcuts: [],                       // no numbered shortcuts for file sources in Phase 1
            isSelected: item.isSelected
        ) {
            Text(verbatim: item.title)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .onTapGesture { location in
            // Emulate HistoryItemView behavior: right area = copy; else toggle selection
            let copyAreaThreshold: CGFloat = 60
            let frameWidth: CGFloat = 300  // Approximate width
            
            if location.x > (frameWidth - copyAreaThreshold) {
                // Copy action
                item.copyToClipboard()
                // Optionally close the popup after copy
                appState.popup.close()
            } else {
                // Toggle selection using centralized system
                contentManager.toggleSelection(item.id)
                item.isSelected = contentManager.isSelected(item.id)
                appState.updateFooterItemVisibility()
            }
        }
        .onHover { hovering in
            if hovering {
                appState.selectWithoutScrolling(item.id)
            }
        }
    }
}