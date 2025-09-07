import SwiftUI
import Defaults

@MainActor
private extension UniversalItemView {
    // ~200ms feels good; wire to Defaults if you want.
    static var previewHoverThrottler = Throttler(minimumDelay: 0.2)
}

struct UniversalItemView: View {
    @Bindable var item: UniversalItemDecorator
    @Environment(AppState.self) private var appState
    @Environment(ContentManager.self) private var contentManager
    
    var body: some View {
        Group {
            if item.base.isFolder {
                // Use folder tree view for folders
                FolderTreeItemView(item: item)
            } else {
                // Use regular file view with indentation
                HStack(spacing: 0) {
                    // Indentation for depth - files align with folder content 
                    if item.base.depth > 0 {
                        Spacer()
                            .frame(width: CGFloat(item.base.depth) * 24.0)  // Increased from 20 to 24 for more child indentation
                    }
                    
                    ListItemView(
                        id: item.id,
                        appIcon: (item.base.sourceId == "prompts" ? nil : item.appIcon),        // Show app icons for all sources except Prompts
                        image: item.image,
                        accessoryImage: nil,
                        attributedTitle: nil,
                        shortcuts: [],                       // no numbered shortcuts for file sources in Phase 1
                        isSelected: item.isSelected,
                        selectionSymbol: (item.isExample ? "pencil.circle" : "checkmark.circle.fill"),
                        selectionSymbolColor: (item.isExample ? .yellow : .white),
                        selectionBackgroundColor: (item.isExample ? .yellow : nil),
                        onCopyAction: { item.copyToClipboard() }
                    ) {
                        Text(verbatim: item.title)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .onTapGesture { location in
                        // Check if click is in the checkbox/selection area (right 60 pixels)
                        let selectionAreaThreshold: CGFloat = 42
                        let frameWidth: CGFloat = 300  // Approximate width
                        
                        if location.x > (frameWidth - selectionAreaThreshold) && item.isSelected {
                            // Toggle example state when clicking the selected checkmark area
                            contentManager.toggleExample(item.id)
                        } else {
                            // Special handling for Prompts: add as chip instead of aggregated selection
                            if item.base.sourceId == "prompts",
                               !(item.base.uniformTypeIdentifier?.hasPrefix("org.nozzle.command.") ?? false),
                               let url = item.base.fileURL {
                                appState.addPromptChip(url: url)
                                // Keep preview focused on this prompt
                                let previous = contentManager.lastNonPromptsSourceId
                                contentManager.activeSourceId = "prompts"
                                // Focus for preview and align hover/selection
                                contentManager.focus(item.id)
                                appState.selectWithoutScrolling(item.id)
                                appState.updateFooterItemVisibility()
                                appState.requestFocusInput()
                                // Return to the previous tab after adding the chip
                                contentManager.activeSourceId = previous
                            } else {
                                // Update focus for preview
                                contentManager.focus(item.id)
                                // Toggle selection using centralized system
                                contentManager.toggleSelection(item.id)
                                appState.updateFooterItemVisibility()
                            }
                        }
                    }
                    .onHover { hovering in
                        if hovering {
                            // Debounce focus so we only preview when the pointer "dwells"
                            UniversalItemView.previewHoverThrottler.minimumDelay = Double(Defaults[.hoverPreviewDelay]) / 1000
                            UniversalItemView.previewHoverThrottler.throttle {
                                // If the item is still hovered after the delay, focus it
                                contentManager.focus(item.id)
                            }
                        } else {
                            UniversalItemView.previewHoverThrottler.cancel()
                        }
                    }
                }
            }
        }
        .contextMenu {
            if item.base.sourceId == "prompts", let url = item.base.fileURL {
                Button("New") {
                    (contentManager.sources["prompts"] as? PromptsSource)?.createNewPrompt()
                }
                
                Button("Add") {
                    let currentText = appState.isSearchMode ? appState.history.searchQuery : appState.promptText
                    (contentManager.sources["prompts"] as? PromptsSource)?.createNewPrompt(initialContents: currentText)
                }
                
                Divider()
                
                Button("Apply to input") {
                    (contentManager.sources["prompts"] as? PromptsSource)?.applyPrompt(at: url)
                    appState.addPromptChip(url: url)
                    appState.isSearchMode = false
                }
                Divider()
                Button("Copy") {
                    item.copyToClipboard()
                }
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                Button("Duplicate") {
                    (contentManager.sources["prompts"] as? PromptsSource)?.duplicatePrompt(at: url)
                }
                Button("Delete", role: .destructive) {
                    (contentManager.sources["prompts"] as? PromptsSource)?.deletePrompt(at: url)
                }
            } else if !item.base.isFolder, let url = item.base.fileURL {
                // Context menu for regular files
                Button("Copy") {
                    item.copyToClipboard()
                }
                
                Button("Copy Path") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(url.path, forType: .string)
                }
                
                Button("Open") {
                    NSWorkspace.shared.open(url)
                }
                
                Divider()
                
                Button(contentManager.isExample(item.id) ? "Remove as Example" : "Mark as Example") {
                    contentManager.toggleExample(item.id)
                }
                
                Button(contentManager.isSelected(item.id) ? "Remove as Context" : "Mark as Context") {
                    contentManager.toggleSelection(item.id)
                    appState.updateFooterItemVisibility()
                }
                
                Divider()
                
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
        }
    }
}
