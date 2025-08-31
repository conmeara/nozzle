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
            
            // Metadata section hidden for now
            // if let metadata = metadata { ... }
        }
        .previewSurfaceStyle()
    }
}