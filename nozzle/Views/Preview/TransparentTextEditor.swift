import SwiftUI
import UniformTypeIdentifiers

struct TransparentTextEditor: NSViewRepresentable {
    final class Coordinator: NSObject, NSTextViewDelegate {
        let parent: TransparentTextEditor
        init(_ parent: TransparentTextEditor) { self.parent = parent }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.onChange?(textView.string)
        }
        
        func textDidEndEditing(_ notification: Notification) {
            parent.onCommit?()
        }
    }
    
    @Binding var text: String
    var onChange: ((String) -> Void)?       // for autosave scheduling
    var onCommit: (() -> Void)?             // for immediate save on blur
    var isRichText: Bool = false
    var font: NSFont? = nil
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.backgroundColor = .clear
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.scrollerStyle = .overlay
        
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textColor = .labelColor                 // auto flips with dark mode
        textView.usesAdaptiveColorMappingForDarkAppearance = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.allowsUndo = true
        
        // Configure text wrapping
        if let container = textView.textContainer {
            container.widthTracksTextView = true
            container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            container.lineBreakMode = .byWordWrapping
        }
        
        // Configure based on text type
        textView.isRichText = isRichText
        if !isRichText, let font = font {
            textView.font = font
        } else if !isRichText {
            textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        }
        
        textView.string = text
        
        scroll.documentView = textView
        return scroll
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text { 
            textView.string = text 
        }
    }
}