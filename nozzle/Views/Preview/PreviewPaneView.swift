import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct PreviewPaneView: View {
    let clipboardItem: HistoryItemDecorator?
    let fileItem: ContentItem?

    var body: some View {
        VStack(spacing: 0) {
            if let clipboardItem = clipboardItem {
                // Check if clipboard item contains file URLs for QuickLook preview
                if clipboardItem.hasFileURL, let fileURL = clipboardItem.item.fileURLs.first {
                    // Use QuickLook for clipboard file URLs
                    QuickLookPreview(url: fileURL)
                        .id(fileURL)
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let image = clipboardItem.previewImage {
                    // Image preview like pre-August 22nd
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(.rect(cornerRadius: DesignConstants.cornerRadius))
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .previewSurfaceStyle()
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
