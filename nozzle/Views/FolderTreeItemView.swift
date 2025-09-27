import SwiftUI
import UniformTypeIdentifiers

struct FolderTreeItemView: View {
    @Bindable var item: UniversalItemDecorator
    @Environment(AppState.self) private var appState
    @Environment(ContentManager.self) private var contentManager
    @State private var itemFrameWidth: CGFloat = 0
    
    private var isExpanded: Bool {
        if let fileSystemSource = contentManager.sources[item.sourceId] as? FileSystemSource,
           let folderPath = item.base.fileURL?.path {
            return fileSystemSource.isFolderExpanded(at: folderPath)
        }
        return false
    }
    
    private var indentationWidth: CGFloat {
        CGFloat(item.base.depth) * 24.0  // Increased to match child file indentation
    }
    
    private var chevronWidth: CGFloat {
        16.0  // Standard chevron button width
    }
    
    private var selectionState: (isSelected: Bool, symbol: String) {
        // If marked as example, override UI to reflect example state
        if contentManager.isExample(item.id) {
            return (true, "pencil.circle.fill")
        }
        let folderSelectionState = contentManager.getFolderSelectionState(item.id)
        switch folderSelectionState {
        case .none:
            return (false, "checkmark.circle.fill")
        case .all:
            return (true, "checkmark.circle.fill") 
        case .partial:
            return (true, "minus.circle.fill")
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Indentation for depth - chevron appears at start of indent level
            if item.base.depth > 0 {
                Spacer()
                    .frame(width: indentationWidth - chevronWidth)
            }
            
            // Expansion triangle - positioned at start of indent level
            Button(action: toggleExpansion) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 12, height: 12)
            }
            .buttonStyle(.plain)
            .frame(width: chevronWidth)
            .padding(.trailing, 2)  // Reduced from 4 to 2 to bring folder closer
            
            // Use existing ListItemView for consistent styling
            ListItemView(
                id: item.id,
                appIcon: folderIcon,
                image: nil,
                accessoryImage: nil,
                attributedTitle: nil,
                shortcuts: [],
                isSelected: selectionState.isSelected,
                selectionSymbol: selectionState.symbol,
                selectionSymbolColor: (contentManager.isExample(item.id) ? .yellow : .white),
                selectionBackgroundColor: (contentManager.isExample(item.id) ? .yellow : nil)
            ) {
                Text(verbatim: item.title)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .onTapGesture { location in
                // Handle folder selection and focus
                let copyAreaThreshold: CGFloat = 42
                let frameWidth = itemFrameWidth > 0 ? itemFrameWidth : 300  // fallback width
                
                let isSelectionAreaClick = location.x > (frameWidth - copyAreaThreshold)

                let clickCount = NSApp.currentEvent?.clickCount ?? 0
                if clickCount >= 2 {
                    appState.isKeyboardNavigating = false
                    if isSelectionAreaClick && contentManager.isSelected(item.id) {
                        contentManager.toggleExample(item.id)
                        contentManager.focus(item.id)
                    } else {
                        contentManager.focus(item.id)
                        contentManager.toggleSelection(item.id)
                        appState.updateFooterItemVisibility()
                    }
                    return
                }

                if isSelectionAreaClick {
                    if !contentManager.isSelected(item.id) {
                        // Copy folder path when not selected
                        item.copyToClipboard()
                        appState.popup.close()
                    } else {
                        // Toggle example state for folders
                        contentManager.toggleExample(item.id)
                        contentManager.focus(item.id)
                    }
                } else {
                    appState.isKeyboardNavigating = false
                    // Single click focuses preview without changing selection state
                    contentManager.focus(item.id)
                }
            }
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            itemFrameWidth = geometry.size.width
                        }
                        .onChange(of: geometry.size) { _, newSize in
                            itemFrameWidth = newSize.width
                        }
                }
            )
            .contextMenu {
                if let url = item.base.fileURL {
                    Button("Copy Path") {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(url.path, forType: .string)
                    }
                    
                    Button("Open in Finder") {
                        NSWorkspace.shared.open(url)
                    }
                    
                    Divider()
                    
                    Button(isExpanded ? "Collapse" : "Expand") {
                        toggleExpansion()
                    }
                    
                    Divider()
                    
                    let folderSelectionState = contentManager.getFolderSelectionState(item.id)
                    if folderSelectionState == .none {
                        Button("Select All Contents") {
                            contentManager.selectFolderChildren(item.id)
                            appState.updateFooterItemVisibility()
                        }
                    } else {
                        Button("Deselect All Contents") {
                            contentManager.deselectFolderChildren(item.id)
                            appState.updateFooterItemVisibility()
                        }
                    }
                    
                    Divider()
                    
                    Button("Remove from Sources", role: .destructive) {
                        contentManager.removeSource(item.sourceId)
                    }
                }
            }
        }
    }
    
    private var folderIcon: ApplicationImage? {
        // Try to get the actual folder icon that reflects content state
        guard let folderPath = item.base.fileURL?.path, !folderPath.isEmpty else {
            // Fallback to generic folder icon
            let genericIcon = NSWorkspace.shared.icon(for: .folder)
            return ApplicationImage(bundleIdentifier: nil, image: genericIcon)
        }
        
        // Force fresh icon lookup without caching
        let folderImage = NSWorkspace.shared.icon(forFile: folderPath)
        return ApplicationImage(bundleIdentifier: nil, image: folderImage)
    }
    
    private func toggleExpansion() {
        guard let fileSystemSource = contentManager.sources[item.sourceId] as? FileSystemSource,
              let folderPath = item.base.fileURL?.path else { return }

        Task {
            await fileSystemSource.toggleFolderExpansion(at: folderPath)
            // Nudge dependent views to refresh
            ContentManager.shared.markSelectedDirty()
        }
    }
}
