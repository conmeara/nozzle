import SwiftUI

struct FolderTreeItemView: View {
    @Bindable var item: UniversalItemDecorator
    @Environment(AppState.self) private var appState
    @Environment(ContentManager.self) private var contentManager
    
    private var isExpanded: Bool {
        if let fileSystemSource = contentManager.sources[item.sourceId] as? FileSystemSource,
           let folderPath = item.base.fileURL?.path {
            return fileSystemSource.isFolderExpanded(at: folderPath)
        }
        return false
    }
    
    private var indentationWidth: CGFloat {
        CGFloat(item.base.depth) * 16.0
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Indentation for depth
            if item.base.depth > 0 {
                Spacer()
                    .frame(width: indentationWidth)
            }
            
            // Expansion triangle
            Button(action: toggleExpansion) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 12, height: 12)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4)
            
            // Use existing ListItemView for consistent styling
            ListItemView(
                id: item.id,
                appIcon: folderIcon,
                image: nil,
                accessoryImage: nil,
                attributedTitle: nil,
                shortcuts: [],
                isSelected: item.isSelected
            ) {
                Text(verbatim: item.title)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .onTapGesture { location in
                // Handle folder selection and focus
                let copyAreaThreshold: CGFloat = 60
                let frameWidth: CGFloat = 300
                
                if location.x > (frameWidth - copyAreaThreshold) {
                    // Copy folder path
                    item.copyToClipboard()
                    appState.popup.close()
                } else {
                    // Focus and selection
                    contentManager.focus(item.id)
                    contentManager.toggleSelection(item.id)
                    item.isSelected = contentManager.isSelected(item.id)
                    appState.updateFooterItemVisibility()
                }
            }
            .onHover { hovering in
                if hovering {
                    appState.selectWithoutScrolling(item.id)
                    contentManager.focus(item.id)
                }
            }
        }
    }
    
    private var folderIcon: ApplicationImage? {
        // Use folder icon instead of file type badge
        let folderImage = NSWorkspace.shared.icon(forFileType: "public.folder")
        return ApplicationImage(bundleIdentifier: nil, image: folderImage)
    }
    
    private func toggleExpansion() {
        guard let fileSystemSource = contentManager.sources[item.sourceId] as? FileSystemSource,
              let folderPath = item.base.fileURL?.path else { return }
        
        Task {
            await fileSystemSource.toggleFolderExpansion(at: folderPath)
        }
    }
}