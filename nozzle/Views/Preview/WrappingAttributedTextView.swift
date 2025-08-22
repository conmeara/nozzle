import SwiftUI

struct WrappingAttributedTextView: NSViewRepresentable {
    let attributedText: NSAttributedString
    
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.backgroundColor = .clear
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.scrollerStyle = .overlay
        
        let tv = NSTextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.drawsBackground = false
        tv.textColor = .labelColor
        tv.usesAdaptiveColorMappingForDarkAppearance = true
        tv.textContainerInset = NSSize(width: 8, height: 8)
        tv.isHorizontallyResizable = false
        tv.isVerticallyResizable = true
        
        // Configure text wrapping
        if let container = tv.textContainer {
            container.widthTracksTextView = true
            container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            container.lineBreakMode = .byWordWrapping
        }
        
        tv.textStorage?.setAttributedString(attributedText)
        
        scroll.documentView = tv
        return scroll
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let tv = nsView.documentView as? NSTextView else { return }
        if tv.attributedString() != attributedText {
            tv.textStorage?.setAttributedString(attributedText)
        }
    }
}