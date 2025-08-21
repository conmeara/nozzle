import SwiftUI
import AppKit

struct PreviewPaneView: View {
    let clipboardItem: HistoryItemDecorator?
    let fileItem: ContentItem?
    
    var body: some View {
        VStack(spacing: 0) {
            if let clipboardItem = clipboardItem {
                // Use existing clipboard preview
                PreviewItemView(item: clipboardItem)
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
        .background(Color(NSColor.controlBackgroundColor))
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
        .background(Color(NSColor.controlBackgroundColor))
    }
}