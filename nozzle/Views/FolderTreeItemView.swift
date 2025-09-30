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
                appState.isKeyboardNavigating = false
                let clickCount = NSApp.currentEvent?.clickCount ?? 0

                // Handle double-click first
                if clickCount >= 2 {
                    contentManager.focus(item.id)
                    let state = contentManager.getFolderSelectionState(item.id)
                    if state == .none {
                        contentManager.selectFolderChildren(item.id)
                    } else {
                        contentManager.deselectFolderChildren(item.id)
                    }
                    appState.updateFooterItemVisibility()
                    return
                }

                // Handle modifier keys before checking click location
                if NSEvent.modifierFlags.contains(.option) {
                    // Option-click: toggle between unselected and example (skip context state)
                    let state = contentManager.getFolderSelectionState(item.id)
                    if contentManager.isExample(item.id) {
                        // Currently example → deselect completely
                        contentManager.toggleExample(item.id)
                        contentManager.deselectFolderChildren(item.id)
                    } else if state != .none {
                        // Currently context (has selections) → switch to example
                        contentManager.toggleExample(item.id)
                    } else {
                        // Currently unselected → select children and mark as example
                        contentManager.selectFolderChildren(item.id)
                        contentManager.toggleExample(item.id)
                    }
                    appState.updateFooterItemVisibility()
                    contentManager.focus(item.id)
                    return
                }

                // Check if click is in the selection area (right 42 pixels)
                let selectionAreaThreshold: CGFloat = 42
                let frameWidth = itemFrameWidth > 0 ? itemFrameWidth : 300

                let isSelectionAreaClick = location.x > (frameWidth - selectionAreaThreshold)

                if isSelectionAreaClick {
                    // Toggle folder selection (select/deselect all children)
                    let state = contentManager.getFolderSelectionState(item.id)
                    if state == .none {
                        contentManager.selectFolderChildren(item.id)
                    } else {
                        // If folder has selections or examples, clear them
                        if contentManager.isExample(item.id) {
                            contentManager.toggleExample(item.id)
                        }
                        contentManager.deselectFolderChildren(item.id)
                    }
                    appState.updateFooterItemVisibility()
                    contentManager.focus(item.id)
                } else {
                    // Regular click: focus preview without changing selection
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
