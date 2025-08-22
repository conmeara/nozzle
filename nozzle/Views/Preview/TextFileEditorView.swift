import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine

struct TextFileEditorView: View {
    let item: ContentItem
    @Environment(ContentManager.self) private var contentManager
    @State private var content: String = ""
    @State private var attributedContent: NSAttributedString?
    @State private var savedAt: Date?
    @State private var autosave: AutoSaveController?
    @State private var loadError = false
    @State private var saveError: String?
    @State private var cancellables = Set<AnyCancellable>()
    
    private var textKind: TextKind {
        if item.isRTF {
            return .rtf
        } else if item.isMarkdown {
            return .markdown
        } else {
            return .plain
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(nsImage: item.fileUTType.map { FileTypeBadgeCache.shared.icon(for: $0) } ?? NSImage(systemSymbolName: "doc", accessibilityDescription: nil)!)
                    .resizable()
                    .frame(width: 16, height: 16)
                Text(item.title)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                if let savedAt {
                    Text("Saved • \(RelativeDateTimeFormatter().localizedString(for: savedAt, relativeTo: .now))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
                
                Text(textKind.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .previewSurfaceStyle()
            
            Divider()
            
            // Editor
            if loadError {
                VStack {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.red.opacity(0.5))
                    Text("Failed to load file")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.textBackgroundColor))
            } else {
                TransparentTextEditor(
                    text: $content,
                    onChange: { _ in
                        autosave?.schedule()
                    },
                    onCommit: {
                        Task { await autosave?.saveNow() }
                    },
                    isRichText: textKind == .rtf
                )
                .previewSurfaceStyle()
                .contextMenu {
                    Button("Save Now") {
                        Task { await autosave?.saveNow() }
                    }
                    .keyboardShortcut("s", modifiers: .command)
                    
                    Button("Revert") {
                        loadContent()
                    }
                    
                    Divider()
                    
                    Button("Copy as Plain Text") {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(content, forType: .string)
                    }
                    
                    if textKind == .rtf, let attributed = attributedContent {
                        Button("Copy as Rich Text") {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.writeObjects([attributed])
                        }
                    }
                    
                    Divider()
                    
                    Button("Show in Finder") {
                        if let url = item.fileURL {
                            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                        }
                    }
                    
                    Button("Open with Default App") {
                        if let url = item.fileURL {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
            
            // Error message
            if let error = saveError {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                    Spacer()
                    Button("Dismiss") {
                        saveError = nil
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                }
                .padding(8)
                .background(Color.red.opacity(0.1))
            }
        }
        .onAppear {
            loadContent()
            setupAutosave()
            setupFocusMonitoring()
        }
        .onChange(of: item.id) { _, _ in
            Task { await autosave?.saveNow() }
            loadContent()
            setupAutosave()
        }
        .onChange(of: contentManager.focusedItemId) { _, newFocus in
            if newFocus != item.id {
                Task { await autosave?.saveNow() }
                // Resume sorting when focus leaves
                if let source = contentManager.sources[item.sourceId] as? FileSystemSource {
                    source.suspendResort(for: nil, enabled: false)
                }
            } else {
                // Suspend sorting while editing
                if let source = contentManager.sources[item.sourceId] as? FileSystemSource {
                    source.suspendResort(for: item.id, enabled: true)
                }
            }
        }
        .onDisappear {
            Task { await autosave?.saveNow() }
            autosave?.cancel()
            cancellables.removeAll()
            // Resume sorting on disappear
            if let source = contentManager.sources[item.sourceId] as? FileSystemSource {
                source.suspendResort(for: nil, enabled: false)
            }
        }
    }
    
    private func loadContent() {
        guard let url = item.fileURL else {
            loadError = true
            return
        }
        
        Task {
            do {
                if textKind == .rtf {
                    let data = try Data(contentsOf: url)
                    if let attributed = NSAttributedString(rtf: data, documentAttributes: nil) {
                        await MainActor.run {
                            self.attributedContent = attributed
                            self.content = attributed.string
                            self.loadError = false
                        }
                    }
                } else {
                    let text = try String(contentsOf: url, encoding: .utf8)
                    await MainActor.run {
                        self.content = text
                        self.loadError = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.loadError = true
                }
            }
        }
    }
    
    private func setupAutosave() {
        guard let url = item.fileURL else { return }
        
        autosave = AutoSaveController(
            url: url,
            utType: item.fileUTType,
            content: $content
        )
        autosave?.onSaved = { 
            savedAt = Date()
        }
    }
    
    private func setupFocusMonitoring() {
        // Listen for app deactivation to save immediately
        NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)
            .sink { _ in
                Task { await autosave?.saveNow() }
            }
            .store(in: &cancellables)
    }
    
    private func iconForTextKind(_ kind: TextKind) -> String {
        switch kind {
        case .plain: return "doc.plaintext"
        case .markdown: return "doc.text"
        case .rtf: return "doc.richtext"
        }
    }
}

enum TextKind {
    case plain
    case markdown
    case rtf
    
    var displayName: String {
        switch self {
        case .plain: return "Plain Text"
        case .markdown: return "Markdown"
        case .rtf: return "Rich Text"
        }
    }
}

// MARK: - Utilities

extension TextFileEditorView {
    var relativeDateFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }
}


// MARK: - NSTextView Bridge (removed, using TransparentTextEditor instead)

// The TextEditorBridge struct has been removed as we now use TransparentTextEditor