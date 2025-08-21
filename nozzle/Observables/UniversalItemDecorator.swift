import AppKit
import Observation
import UniformTypeIdentifiers

@Observable @MainActor
final class UniversalItemDecorator: Identifiable, Hashable {
    let id: UUID
    private(set) var base: ContentItem
    let sourceId: String
    
    // Derived UI
    var title: String { base.title }
    var isSelected: Bool {
        didSet { base.isSelected = isSelected }
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
    
    init(_ item: ContentItem) {
        self.id = item.id
        self.base = item
        self.sourceId = item.sourceId
        self.isSelected = item.isSelected
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