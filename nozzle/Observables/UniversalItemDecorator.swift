import AppKit
import Defaults
import Observation
import UniformTypeIdentifiers

@Observable @MainActor
final class UniversalItemDecorator: ListItemDecorator {
    let id: UUID
    private(set) var base: ContentItem
    let sourceId: String
    
    // Cached thumbnail for performance
    private var _thumbnailImage: NSImage?
    
    // Static thumbnail size to match HistoryItemDecorator
    static var thumbnailImageSize: NSSize { 
        NSSize(width: 340, height: Defaults[.imageMaxHeight]) 
    }
    
    // Derived UI
    var title: String {
        // For Prompts, hide the file extension from display
        if base.sourceId == "prompts", let url = base.fileURL {
            return url.deletingPathExtension().lastPathComponent
        }
        return base.title
    }
    var isSelected: Bool {
        ContentManager.shared.isSelected(id)
    }
    var isExample: Bool {
        ContentManager.shared.isExample(id)
    }
    var isVisible: Bool {
        didSet { base.isVisible = isVisible }
    }
    
    // Type badge for file items
    var typeBadgeImage: ApplicationImage? {
        guard let type = base.fileUTType else { return nil }
        let nsImage = FileTypeBadgeCache.shared.icon(for: type)
        return ApplicationImage(bundleIdentifier: nil, image: nsImage)
    }
    
    // Protocol conformance - ListItemDecorator
    var appIcon: ApplicationImage? { typeBadgeImage }
    var image: NSImage? { 
        if _thumbnailImage == nil, 
           let imageData = base.imageData,
           let nsImage = NSImage(data: imageData) {
            // Cache the resized thumbnail on first access
            _thumbnailImage = nsImage.resized(to: UniversalItemDecorator.thumbnailImageSize)
        }
        return _thumbnailImage
    }
    var accessoryImage: NSImage? { nil }
    var attributedTitle: AttributedString? { nil }
    var shortcuts: [KeyShortcut] { [] } // No numbered shortcuts for file sources in Phase 1
    
    init(_ item: ContentItem) {
        self.id = item.id
        self.base = item
        self.sourceId = item.sourceId
        self.isVisible = item.isVisible
    }
    
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    nonisolated static func == (lhs: UniversalItemDecorator, rhs: UniversalItemDecorator) -> Bool {
        lhs.id == rhs.id
    }
    
    // Cross-source common action
    func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        if let url = base.fileURL {
            // For files, write the URL to pasteboard
            pasteboard.writeObjects([url as NSURL])
        } else if base.rtfData != nil || base.htmlData != nil || base.plainText != nil {
            // For rich content, write all available formats
            if let rtfData = base.rtfData {
                pasteboard.setData(rtfData, forType: .rtf)
            }
            if let htmlData = base.htmlData {
                pasteboard.setData(htmlData, forType: .html)
            }
            if let plainText = base.plainText {
                pasteboard.setString(plainText, forType: .string)
            }
        } else if let imageData = base.imageData {
            // For images, write the image data
            if let image = NSImage(data: imageData) {
                pasteboard.writeObjects([image])
            }
        }
    }
}
