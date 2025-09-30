import SwiftUI
import Defaults
import AppKit
import KeyboardShortcuts

// Local inline text field that selects only the base name (excluding extension)
private struct InlineBaseNameTextField: NSViewRepresentable {
    @Binding var text: String
    let ext: String
    let onSubmit: () -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField(string: text)
        tf.isBordered = false
        tf.isBezeled = false
        tf.drawsBackground = false
        tf.focusRingType = .none
        tf.target = context.coordinator
        tf.action = #selector(Coordinator.submit(_:))
        tf.delegate = context.coordinator
        DispatchQueue.main.async { selectBase(tf) }
        return tf
    }

    func updateNSView(_ tf: NSTextField, context: Context) {
        if tf.stringValue != text { tf.stringValue = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: InlineBaseNameTextField
        init(_ parent: InlineBaseNameTextField) { self.parent = parent }
        
        @objc func submit(_ sender: Any?) {
            // Update the binding with the current text field value before submitting
            if let textField = sender as? NSTextField {
                parent.text = textField.stringValue
            }
            parent.onSubmit()
        }
        
        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.cancelOperation(_:)):
                parent.onCancel(); return true
            case #selector(NSResponder.insertNewline(_:)):
                // Update text before submitting
                if let textField = control as? NSTextField {
                    parent.text = textField.stringValue
                }
                parent.onSubmit(); return true
            default: return false
            }
        }
    }

    private func selectBase(_ tf: NSTextField) {
        tf.window?.makeFirstResponder(tf)
        let s = tf.stringValue as NSString
        let hasExt = s.range(of: ".\(ext)", options: [.backwards, .anchored]).location != NSNotFound
        let baseLen = hasExt ? max(0, s.length - (ext.count + 1)) : s.length
        if let editor = tf.window?.fieldEditor(true, for: tf) {
            editor.selectedRange = NSRange(location: 0, length: baseLen)
        }
    }
}

struct UniversalItemView: View {
    @Bindable var item: UniversalItemDecorator
    @Environment(AppState.self) private var appState
    @Environment(ContentManager.self) private var contentManager
    @State private var isRenaming: Bool = false
    @State private var editingName: String = ""
    @State private var itemFrameWidth: CGFloat = 0
    @FocusState private var renameFocused: Bool
    
    var body: some View {
        Group {
            if item.base.isFolder {
                // Use folder tree view for folders
                FolderTreeItemView(item: item)
            } else {
                // Use regular file view with indentation
                HStack(spacing: 0) {
                    // Indentation for depth (skip in Aggregated view — flat list of pasteable items)
                    if item.base.depth > 0 && contentManager.activeSourceId != "aggregated" {
                        Spacer()
                            .frame(width: CGFloat(item.base.depth) * 24.0)
                    }
                    
                    ListItemView(
                        id: item.id,
                        appIcon: (item.base.sourceId == "prompts" ? nil : item.appIcon),
                        image: item.image,
                        accessoryImage: nil,
                        attributedTitle: nil,
                        shortcuts: [],
                        isSelected: item.isSelected,
                        selectionSymbol: (item.isExample ? "pencil.circle.fill" : "checkmark.circle.fill"),
                        selectionSymbolColor: .white,
                        selectionBackgroundColor: (item.isExample ? .yellow : nil),
                        isPromptItem: item.base.sourceId == "prompts",
                        onPlusButtonClick: { addPromptToInput() }
                    ) { titleView() }
                    .onMouseMove {
                        // Mouse movement turns off keyboard navigation so pointer clicks drive focus
                        appState.isKeyboardNavigating = false
                    }
                    .onTapGesture { location in
                        if isRenaming { finishRename(); return }
                        appState.isKeyboardNavigating = false
                        let clickCount = NSApp.currentEvent?.clickCount ?? 0

                        // Handle double-click first
                        if clickCount >= 2 {
                            if let activeRename = contentManager.renameActiveItemId, activeRename != item.id {
                                NotificationCenter.default.post(name: .CommitActiveRename, object: nil)
                            }
                            if item.base.sourceId == "prompts",
                               !(item.base.uniformTypeIdentifier?.hasPrefix("org.nozzle.command.") ?? false),
                               let url = item.base.fileURL {
                                appState.addPromptChip(url: url)
                                let previous = contentManager.lastNonPromptsSourceId
                                contentManager.activeSourceId = "prompts"
                                contentManager.focus(item.id)
                                contentManager.toggleSelection(item.id)
                                appState.updateFooterItemVisibility()
                                appState.requestFocusInput()
                                contentManager.activeSourceId = previous
                            } else {
                                contentManager.focus(item.id)
                                contentManager.toggleSelection(item.id)
                                appState.updateFooterItemVisibility()
                            }
                            return
                        }

                        // If another row is in rename mode, exit rename mode first
                        if let activeRename = contentManager.renameActiveItemId, activeRename != item.id {
                            NotificationCenter.default.post(name: .CommitActiveRename, object: nil)
                            return
                        }

                        // Handle modifier keys before checking click location
                        if NSEvent.modifierFlags.contains(.option) {
                            // Option-click: toggle between unselected and example (skip context state)
                            if contentManager.isExample(item.id) {
                                // Currently example → deselect completely
                                contentManager.toggleExample(item.id)
                                contentManager.toggleSelection(item.id)
                            } else if item.isSelected {
                                // Currently context → switch to example
                                contentManager.toggleExample(item.id)
                            } else {
                                // Currently unselected → select and mark as example
                                contentManager.toggleSelection(item.id)
                                contentManager.toggleExample(item.id)
                            }
                            appState.updateFooterItemVisibility()
                            contentManager.focus(item.id)
                            return
                        }

                        if item.base.sourceId == "prompts", NSEvent.modifierFlags.contains(.command) {
                            // Command-click (Prompts only): rename
                            beginRename()
                            return
                        }

                        // Check if click is in the selection area (right 42 pixels)
                        let selectionAreaThreshold: CGFloat = 42
                        let frameWidth = itemFrameWidth > 0 ? itemFrameWidth : 300

                        let isSelectionAreaClick = location.x > (frameWidth - selectionAreaThreshold)

                        if isSelectionAreaClick {
                            // Toggle selection on/off (also clears example state if deselecting)
                            if item.isSelected && contentManager.isExample(item.id) {
                                contentManager.toggleExample(item.id)
                            }
                            contentManager.toggleSelection(item.id)
                            appState.updateFooterItemVisibility()
                            contentManager.focus(item.id)
                        } else {
                            // Regular click: focus preview without changing selection
                            contentManager.focus(item.id)
                        }
                    }
                }
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
            if item.base.sourceId == "prompts", let url = item.base.fileURL {
                Button("New") {
                    (contentManager.sources["prompts"] as? PromptsSource)?.createNewPrompt()
                }
                
                Button("Add") {
                    let currentText = appState.isSearchMode ? appState.history.searchQuery : appState.promptText
                    (contentManager.sources["prompts"] as? PromptsSource)?.createNewPrompt(initialContents: currentText)
                }
                
                Divider()

                Button("Add to Input") {
                    addPromptToInput()
                }

                Button("Add as Prompt Chip") {
                    appState.addPromptChip(url: url)
                    contentManager.toggleSelection(item.id)
                    appState.updateFooterItemVisibility()
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
                Button("Rename…") {
                    beginRename()
                }
                Button("Delete", role: .destructive) {
                    (contentManager.sources["prompts"] as? PromptsSource)?.deletePrompt(at: url)
                }
                .keyboardShortcut(
                    .backspace,
                    modifiers: KeyboardShortcuts.Shortcut(name: .delete)?.toEventModifiers() ?? [.option]
                )

                Divider()

                Button(Defaults[.showShortcutsBar] ? "Hide Shortcuts Bar" : "Show Shortcuts Bar") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        Defaults[.showShortcutsBar].toggle()
                    }
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
                
                // Put Context above Example
                Button(contentManager.isSelected(item.id) ? "Remove as Context" : "Mark as Context") {
                    contentManager.toggleSelection(item.id)
                    appState.updateFooterItemVisibility()
                }
                .keyboardShortcut(.tab)
                
                Button(contentManager.isExample(item.id) ? "Remove as Example" : "Mark as Example") {
                    contentManager.toggleExample(item.id)
                }
                
                Divider()

                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }

                Divider()

                Button(Defaults[.showShortcutsBar] ? "Hide Shortcuts Bar" : "Show Shortcuts Bar") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        Defaults[.showShortcutsBar].toggle()
                    }
                }
            }
        }
        .onChange(of: contentManager.pendingRenameItemId) { _, newValue in
            guard let pending = newValue else { return }
            if pending == item.id {
                beginRename()
                // Clear the request so other rows don't respond
                contentManager.pendingRenameItemId = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .CommitActiveRename)) { _ in
            if isRenaming { finishRename() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .CancelActiveRename)) { _ in
            if isRenaming { cancelRename() }
        }
        .onAppear {
            // If a rename was requested before this row appeared, handle it now
            if contentManager.pendingRenameItemId == item.id {
                beginRename()
                contentManager.pendingRenameItemId = nil
            }
        }
        .onChange(of: contentManager.renameActiveItemId) { _, active in
            // If another row becomes the active rename or rename is cleared, exit local rename mode
            if let active, active != item.id { if isRenaming { isRenaming = false } }
        }
    }
}

// MARK: - Rename helpers (Prompts only)
private extension UniversalItemView {
    @ViewBuilder
    func titleView() -> some View {
        if isRenaming && item.base.sourceId == "prompts" && !item.base.isFolder {
            let ext = (item.base.fileURL?.pathExtension.isEmpty == false)
                ? (item.base.fileURL?.pathExtension ?? Defaults[.promptsFileExtension])
                : Defaults[.promptsFileExtension]
            InlineBaseNameTextField(
                text: $editingName,
                ext: ext,
                onSubmit: { finishRename() },
                onCancel: { cancelRename() }
            )
            .focused($renameFocused)
            .onChange(of: renameFocused) { _, focused in
                if !focused { finishRename() }
            }
            // Swallow row-level taps while renaming to ensure commit-first
            .highPriorityGesture(TapGesture())
            // Last-chance commit if the row disappears due to refresh/navigation
            .onDisappear { if isRenaming { finishRename() } }
        } else {
            Text(verbatim: item.title)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
    func beginRename() {
        guard item.base.sourceId == "prompts", !item.base.isFolder else { return }
        contentManager.focus(item.id)
        editingName = displayNameWithoutExtension()
        isRenaming = true
        contentManager.renameActiveItemId = item.id
        DispatchQueue.main.async { renameFocused = true }
    }

    func finishRename() {
        guard isRenaming else { return }
        let newBase = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = item.base.fileURL else { return }
        let currentBase = url.deletingPathExtension().lastPathComponent
        // Empty name: keep editing, beep, refocus
        if newBase.isEmpty {
            NSSound.beep()
            DispatchQueue.main.async { renameFocused = true }
            return
        }
        // No change: exit rename mode quietly
        if newBase == currentBase {
            isRenaming = false
            contentManager.renameActiveItemId = nil
            return
        }
        // Build expected new URL for optimistic update
        let ext = url.pathExtension.isEmpty ? Defaults[.promptsFileExtension] : url.pathExtension
        let newURL = url.deletingLastPathComponent().appendingPathComponent(newBase).appendingPathExtension(ext)
        
        // Optimistic update - show new name immediately  
        contentManager.optimisticallyUpdateItem(item.id, sourceId: "prompts", newFileURL: newURL, newTitle: newBase)
        
        // Attempt rename; only exit on success
        if let _ = (contentManager.sources["prompts"] as? PromptsSource)?.renamePrompt(at: url, to: newBase) {
            // Success: keep optimistic update, async refresh will sync any discrepancies
            isRenaming = false
            contentManager.renameActiveItemId = nil
        } else {
            // Failure: revert optimistic update and keep editing so user can fix
            contentManager.revertOptimisticUpdate(item.id, sourceId: "prompts")
            DispatchQueue.main.async { renameFocused = true }
        }
    }

    func displayNameWithoutExtension() -> String {
        if let url = item.base.fileURL {
            return url.deletingPathExtension().lastPathComponent
        }
        return item.title
    }

    func cancelRename() {
        isRenaming = false
        contentManager.renameActiveItemId = nil
    }

    func addPromptToInput() {
        guard item.base.sourceId == "prompts", let url = item.base.fileURL else { return }
        (contentManager.sources["prompts"] as? PromptsSource)?.addPromptToInput(at: url)
        contentManager.focus(item.id)
        appState.isSearchMode = false
        appState.requestFocusInput()
    }
}
