import SwiftUI
import AppKit

struct PreviewPaneView: View {
    let clipboardItem: HistoryItemDecorator?
    let fileItem: ContentItem?
    
    var body: some View {
        VStack(spacing: 0) {
            if let clipboardItem = clipboardItem {
                // Use enhanced clipboard preview with proper wrapping
                EnhancedClipboardPreview(item: clipboardItem)
            } else if let fileItem = fileItem {
                // Route to appropriate file preview
                if fileItem.isImage {
                    ImagePreviewView(item: fileItem)
                } else if fileItem.isText {
                    TextFileEditorView(item: fileItem)
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

// Enhanced clipboard preview with proper text wrapping
struct EnhancedClipboardPreview: View {
    let item: HistoryItemDecorator
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let image = item.previewImage {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 600)
                        .padding()
                }
            } else {
                // Use WrappingAttributedTextView for proper text wrapping
                let attributedText: NSAttributedString = {
                    if let rtf = item.item.rtf {
                        return rtf
                    } else if let html = item.item.html {
                        return html
                    } else {
                        return NSAttributedString(string: item.text)
                    }
                }()
                
                WrappingAttributedTextView(attributedText: attributedText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }
            
            Divider()
                .padding(.vertical)
            
            // Metadata section
            VStack(alignment: .leading, spacing: 8) {
                if let application = item.application {
                    HStack(spacing: 3) {
                        Text("Application", tableName: "PreviewItemView")
                        Image(nsImage: item.applicationImage.nsImage)
                            .resizable()
                            .frame(width: 11, height: 11)
                        Text(application)
                    }
                }
                
                HStack(spacing: 3) {
                    Text("FirstCopyTime", tableName: "PreviewItemView")
                    Text(item.item.firstCopiedAt, style: .date)
                    Text(item.item.firstCopiedAt, style: .time)
                }
                
                HStack(spacing: 3) {
                    Text("LastCopyTime", tableName: "PreviewItemView")
                    Text(item.item.lastCopiedAt, style: .date)
                    Text(item.item.lastCopiedAt, style: .time)
                }
                
                HStack(spacing: 3) {
                    Text("NumberOfCopies", tableName: "PreviewItemView")
                    Text(String(item.item.numberOfCopies))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding()
        }
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