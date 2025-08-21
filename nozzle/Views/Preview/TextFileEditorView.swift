import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct TextFileEditorView: View {
    let item: ContentItem
    @State private var content: String = ""
    @State private var attributedContent: NSAttributedString?
    @State private var isDirty = false
    @State private var loadError = false
    @State private var saveError: String?
    
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
            HStack {
                Image(systemName: iconForTextKind(textKind))
                    .foregroundColor(.secondary)
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)
                if isDirty {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                }
                Spacer()
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
            .background(Color(NSColor.controlBackgroundColor))
            
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
                TextEditorBridge(
                    text: $content,
                    attributedText: $attributedContent,
                    isDirty: $isDirty,
                    textKind: textKind,
                    fileURL: item.fileURL
                )
                .background(Color(NSColor.textBackgroundColor))
                .contextMenu {
                    if isDirty {
                        Button("Save") {
                            save()
                        }
                        .keyboardShortcut("s", modifiers: .command)
                        
                        Button("Revert") {
                            loadContent()
                        }
                        
                        Divider()
                    }
                    
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
        }
        .onChange(of: item.id) { _, _ in
            loadContent()
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
                            self.isDirty = false
                            self.loadError = false
                        }
                    }
                } else {
                    let text = try String(contentsOf: url, encoding: .utf8)
                    await MainActor.run {
                        self.content = text
                        self.isDirty = false
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
    
    private func save() {
        guard let url = item.fileURL else { return }
        
        do {
            if textKind == .rtf, let attributed = attributedContent {
                let data = try attributed.data(
                    from: NSRange(location: 0, length: attributed.length),
                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
                )
                try data.write(to: url)
            } else {
                try content.write(to: url, atomically: true, encoding: .utf8)
            }
            isDirty = false
            saveError = nil
        } catch {
            saveError = "Failed to save: \(error.localizedDescription)"
        }
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

// MARK: - NSTextView Bridge

struct TextEditorBridge: NSViewRepresentable {
    @Binding var text: String
    @Binding var attributedText: NSAttributedString?
    @Binding var isDirty: Bool
    let textKind: TextKind
    let fileURL: URL?
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.delegate = context.coordinator
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.allowsUndo = true
        
        // Configure based on text kind
        switch textKind {
        case .rtf:
            textView.isRichText = true
            textView.importsGraphics = false
            textView.usesInspectorBar = false
        case .plain, .markdown:
            textView.isRichText = false
            textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        }
        
        // Set initial content
        if textKind == .rtf, let attributed = attributedText {
            textView.textStorage?.setAttributedString(attributed)
        } else {
            textView.string = text
        }
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
        
        // Only update if not currently editing
        if !context.coordinator.isUpdating {
            if textKind == .rtf, let attributed = attributedText {
                if textView.attributedString() != attributed {
                    textView.textStorage?.setAttributedString(attributed)
                }
            } else {
                if textView.string != text {
                    textView.string = text
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TextEditorBridge
        var isUpdating = false
        
        init(_ parent: TextEditorBridge) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            isUpdating = true
            parent.text = textView.string
            if parent.textKind == .rtf {
                parent.attributedText = textView.attributedString()
            }
            parent.isDirty = true
            isUpdating = false
        }
    }
}