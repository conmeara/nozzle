import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct PreviewPaneView: View {
    let clipboardItem: HistoryItemDecorator?
    let fileItem: ContentItem?
    @Environment(ContentManager.self) private var contentManager

    var body: some View {
        VStack(spacing: 0) {
            if let clipboardItem = clipboardItem {
                // Prefer in-memory image bytes for clipboard images to avoid sandbox issues with external URLs
                if let image = clipboardItem.previewImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(.rect(cornerRadius: DesignConstants.cornerRadius))
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .previewSurfaceStyle()
                } else if clipboardItem.hasFileURL, let fileURL = clipboardItem.item.fileURLs.first {
                    // Non-image clipboard files: use QuickLook
                    QuickLookPreview(url: fileURL)
                        .id(fileURL)
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Plain text preview for clipboard text (no metadata)
                    PlainTextPreview(
                        text: clipboardItem.text,
                        metadata: nil
                    )
                }
            } else if let fileItem = fileItem {
                // Route to appropriate preview for universal/selected items
                if fileItem.sourceId == "prompts",
                   fileItem.fileURL != nil,
                   (fileItem.isText || fileItem.isMarkdown || fileItem.uniformTypeIdentifier == UTType.plainText.identifier) {
                    // Editable preview for prompt files
                    PromptEditorView(item: fileItem)
                } else if fileItem.sourceType == .clipboard {
                    // Clipboard-backed selected item: prioritize file URLs for QuickLook
                    if let data = fileItem.imageData, let image = NSImage(data: data) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(.rect(cornerRadius: DesignConstants.cornerRadius))
                            .padding()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .previewSurfaceStyle()
                    } else if fileItem.isFolder, let fileURL = fileItem.fileURL {
                        FolderPreviewView(folderURL: fileURL, item: fileItem)
                    } else if !fileItem.isFolder, let fileURL = fileItem.fileURL {
                        // Use QuickLook for clipboard file URLs before falling back to plain text
                        QuickLookPreview(url: fileURL)
                            .id(fileURL)
                            .padding()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let text = fileItem.plainText {
                        PlainTextPreview(
                            text: text,
                            metadata: nil
                        )
                    } else {
                        EmptyPreviewView()
                    }
                } else if fileItem.sourceType == .screenshot {
                    // Screenshot items: show thumbnail preview
                    if let data = fileItem.imageData, let image = NSImage(data: data) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(.rect(cornerRadius: DesignConstants.cornerRadius))
                            .padding()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .previewSurfaceStyle()
                    } else {
                        EmptyPreviewView()
                    }
                } else if fileItem.isFolder, let fileURL = fileItem.fileURL {
                    FolderPreviewView(folderURL: fileURL, item: fileItem)
                } else if !fileItem.isFolder, let fileURL = fileItem.fileURL {
                    // Use Quick Look for all file-backed items in universal tabs (text and non-text)
                    QuickLookPreview(url: fileURL)
                        .id(fileURL)
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    EmptyPreviewView()
                }
            } else {
                NoSelectionView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .previewSurfaceStyle()
        // Clicking into the preview should commit any active inline rename first
        .simultaneousGesture(TapGesture().onEnded {
            if contentManager.renameActiveItemId != nil {
                NotificationCenter.default.post(name: .CommitActiveRename, object: nil)
            }
        })
        // Swap preview content immediately without implicit fades
        .transaction { transaction in
            transaction.animation = nil
        }
    }
}

struct NoSelectionView: View {
    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .previewSurfaceStyle()
    }
}

struct EmptyPreviewView: View {
    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "questionmark.folder")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text("Preview not available")
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .previewSurfaceStyle()
    }
}
