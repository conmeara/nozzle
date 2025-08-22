import SwiftUI

struct PreviewSurfaceStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(.primary)      // auto flips on dark/light
            .background(.clear)             // fully transparent
            .compositingGroup()             // keeps transparency
            .clipped()                      // prevents bleed into list
    }
}

extension View {
    func previewSurfaceStyle() -> some View {
        modifier(PreviewSurfaceStyle())
    }
}