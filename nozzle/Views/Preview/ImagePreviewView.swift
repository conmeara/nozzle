import SwiftUI
import AppKit

struct ImagePreviewView: View {
    let item: ContentItem
    @State private var nsImage: NSImage?
    @State private var loadError = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "photo")
                    .foregroundColor(.secondary)
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if let fileSize = item.fileSize {
                    Text(formatFileSize(fileSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .previewSurfaceStyle()
            
            Divider()
            
            // Image content
            if let nsImage = nsImage {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 600)
                        .padding()
                }
                .previewSurfaceStyle()
                .contextMenu {
                    Button("Copy Image") {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.writeObjects([nsImage])
                    }
                    Button("Show in Finder") {
                        if let url = item.fileURL {
                            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                        }
                    }
                    Divider()
                    if let url = item.fileURL {
                        Button("Open with Default App") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            } else if loadError {
                VStack {
                    Spacer()
                    Image(systemName: "photo.fill.on.rectangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.red.opacity(0.5))
                    Text("Failed to load image")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .previewSurfaceStyle()
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .previewSurfaceStyle()
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: item.id) { _, _ in
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = item.fileURL else {
            loadError = true
            return
        }
        
        Task {
            do {
                let data = try Data(contentsOf: url)
                if let image = NSImage(data: data) {
                    await MainActor.run {
                        self.nsImage = image
                        self.loadError = false
                    }
                } else {
                    await MainActor.run {
                        self.loadError = true
                    }
                }
            } catch {
                await MainActor.run {
                    self.loadError = true
                }
            }
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}