import SwiftUI

struct PlainTextPreview: View {
    let text: String
    let metadata: PreviewMetadata?
    
    struct PreviewMetadata {
        let application: String?
        let applicationImage: NSImage?
        let firstCopiedAt: Date?
        let lastCopiedAt: Date?
        let numberOfCopies: Int?
        let fileName: String?
        let fileSize: Int64?
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Text content
            ScrollView {
                Text(text)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            if let metadata = metadata {
                Divider()
                    .padding(.vertical)
                
                // Metadata section
                VStack(alignment: .leading, spacing: 8) {
                    // File-specific metadata
                    if let fileName = metadata.fileName {
                        HStack(spacing: 3) {
                            Text("File")
                            Text(fileName)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    
                    if let fileSize = metadata.fileSize {
                        HStack(spacing: 3) {
                            Text("Size")
                            Text(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
                        }
                    }
                    
                    // Clipboard-specific metadata
                    if let application = metadata.application,
                       let applicationImage = metadata.applicationImage {
                        HStack(spacing: 3) {
                            Text("Application", tableName: "PreviewItemView")
                            Image(nsImage: applicationImage)
                                .resizable()
                                .frame(width: 11, height: 11)
                            Text(application)
                        }
                    }
                    
                    if let firstCopiedAt = metadata.firstCopiedAt {
                        HStack(spacing: 3) {
                            Text("FirstCopyTime", tableName: "PreviewItemView")
                            Text(firstCopiedAt, style: .date)
                            Text(firstCopiedAt, style: .time)
                        }
                    }
                    
                    if let lastCopiedAt = metadata.lastCopiedAt {
                        HStack(spacing: 3) {
                            Text("LastCopyTime", tableName: "PreviewItemView")
                            Text(lastCopiedAt, style: .date)
                            Text(lastCopiedAt, style: .time)
                        }
                    }
                    
                    if let numberOfCopies = metadata.numberOfCopies {
                        HStack(spacing: 3) {
                            Text("NumberOfCopies", tableName: "PreviewItemView")
                            Text(String(numberOfCopies))
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding()
            }
        }
        .previewSurfaceStyle()
    }
}