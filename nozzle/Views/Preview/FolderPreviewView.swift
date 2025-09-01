import SwiftUI

struct FolderPreviewView: View {
    let folderURL: URL
    let item: ContentItem
    
    var body: some View {
        VStack {
            Image(nsImage: NSWorkspace.shared.icon(forFile: folderURL.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 128, height: 128)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .previewSurfaceStyle()
    }
}