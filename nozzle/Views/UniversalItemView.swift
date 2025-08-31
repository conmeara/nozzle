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
                        appIcon: item.typeBadgeImage,        // Show file type badge
                        image: nil,                          // optional: lightweight thumbs in Phase 2
                        accessoryImage: nil,
                        attributedTitle: nil,
                        shortcuts: [],                       // no numbered shortcuts for file sources in Phase 1
                        isSelected: item.isSelected,
                        selectionSymbol: (item.isExample ? "pencil.circle" : "checkmark.circle.fill"),
                        selectionSymbolColor: (item.isExample ? .yellow : .white),
                        selectionBackgroundColor: (item.isExample ? .yellow : nil)
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
                            if !item.isSelected {
                                // Copy action
                                item.copyToClipboard()
                                // Optionally close the popup after copy
                                appState.popup.close()
                            } else if contentManager.canToggleExample(item.id) {
                                // Toggle example state when clicking the selected checkmark area
                                contentManager.toggleExample(item.id)
                            } else {
                                // Not textual; ignore toggle
                            }
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
            }
        }
    }
}
