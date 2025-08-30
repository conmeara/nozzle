import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct PreviewPaneView: View {
    let clipboardItem: HistoryItemDecorator?
    let fileItem: ContentItem?

    // Cancelable text loading for file previews to avoid blocking UI
    @State private var loadedText: String = ""
    @State private var isLoadingText: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            if let clipboardItem = clipboardItem {
                // Use plain text preview for clipboard
                if let image = clipboardItem.previewImage {
                    // Image preview like pre-August 22nd
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(.rect(cornerRadius: 5))
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .previewSurfaceStyle()
                } else {
                    // Plain text preview for clipboard text
                    PlainTextPreview(
                        text: clipboardItem.text,
                        metadata: PlainTextPreview.PreviewMetadata(
                            application: clipboardItem.application,
                            applicationImage: clipboardItem.applicationImage.nsImage,
                            firstCopiedAt: clipboardItem.item.firstCopiedAt,
                            lastCopiedAt: clipboardItem.item.lastCopiedAt,
                            numberOfCopies: clipboardItem.item.numberOfCopies,
                            fileName: nil,
                            fileSize: nil
                        )
                    )
                }
            } else if let fileItem = fileItem {
                // Route to appropriate file preview
                if fileItem.sourceId == "prompts",
                   fileItem.fileURL != nil,
                   (fileItem.isText || fileItem.isMarkdown || fileItem.uniformTypeIdentifier == UTType.plainText.identifier) {
                    // Editable preview for prompt files
                    PromptEditorView(item: fileItem)
                } else if fileItem.isText {
                    // Plain text preview for files with cancelable loading
                    PlainTextPreview(
                        text: loadedText,
                        metadata: PlainTextPreview.PreviewMetadata(
                            application: nil,
                            applicationImage: nil,
                            firstCopiedAt: nil,
                            lastCopiedAt: nil,
                            numberOfCopies: nil,
                            fileName: fileItem.title,
                            fileSize: fileItem.fileSize
                        )
                    )
                    .overlay(alignment: .topLeading) {
                        if isLoadingText {
                            ProgressView().controlSize(.small).padding(8)
                        }
                    }
                } else if let fileURL = fileItem.fileURL {
                    // QuickLook preview for all other file types
                    QuickLookPreview(url: fileURL)
                } else {
                    EmptyPreviewView()
                }
            } else {
                NoSelectionView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .previewSurfaceStyle()
        // Load/cancel text preview work when focus changes
        .task(id: fileItem?.id) {
            // Reset state for new focus
            loadedText = ""
            isLoadingText = false
            guard let item = fileItem, item.isText else { return }
            isLoadingText = true
            // Perform blocking IO off the main actor; inherits cancellation
            let text: String = await Task(priority: .userInitiated) {
                FileContentExtractor.extractPlainText(from: item)
            }.value
            guard !Task.isCancelled else { return }
            loadedText = text
            isLoadingText = false
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
            Text("No item selected")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Select an item to preview")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.8))
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
