import SwiftUI
import AppKit

struct PreviewPaneView: View {
    let clipboardItem: HistoryItemDecorator?
    let fileItem: ContentItem?
    
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
                if fileItem.isImage {
                    ImagePreviewView(item: fileItem)
                } else if fileItem.isText {
                    // Plain text preview for files
                    PlainTextPreview(
                        text: FileContentExtractor.extractPlainText(from: fileItem),
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