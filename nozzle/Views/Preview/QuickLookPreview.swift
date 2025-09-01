import SwiftUI
import QuickLookUI

struct QuickLookPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .compact)!
        view.autostarts = true
        view.previewItem = url as NSURL
        return view
    }

    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        // Intentionally a no-op. We key the SwiftUI view with `.id(url)`
        // so Make/Dismantle manage the preview lifecycle. This avoids
        // setting a preview item on a deactivated view during updates.
    }

    static func dismantleNSView(_ nsView: QLPreviewView, coordinator: ()) {
        // Clear to avoid assertions if SwiftUI tears down the view while a new URL is set
        nsView.previewItem = nil
    }
}
