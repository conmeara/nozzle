import AppKit
import UniformTypeIdentifiers

@MainActor
final class FileTypeBadgeCache {
    static let shared = FileTypeBadgeCache()
    private var cache: [String: NSImage] = [:]
    
    private init() {}
    
    func icon(for type: UTType) -> NSImage {
        // Check cache first
        if let cached = cache[type.identifier] {
            return cached
        }
        
        // Create icon based on type
        let img: NSImage
        
        if type.conforms(to: .image) {
            img = NSImage(systemSymbolName: "photo", accessibilityDescription: "Image")!
        } else if type == .rtf || type == .rtfd {
            img = NSImage(systemSymbolName: "doc.richtext", accessibilityDescription: "Rich Text")!
        } else if type == .plainText || type == .utf8PlainText || type == .utf16PlainText {
            img = NSImage(systemSymbolName: "doc.plaintext", accessibilityDescription: "Plain Text")!
        } else if type.identifier == "net.daringfireball.markdown" || type.identifier == "public.markdown" {
            img = NSImage(systemSymbolName: "doc.text", accessibilityDescription: "Markdown")!
        } else if type.conforms(to: .text) {
            img = NSImage(systemSymbolName: "doc.text", accessibilityDescription: "Text")!
        } else {
            // Fallback to workspace icon for the file extension
            if let ext = type.preferredFilenameExtension {
                img = NSWorkspace.shared.icon(forFileType: ext)
            } else {
                img = NSImage(systemSymbolName: "doc", accessibilityDescription: "Document")!
            }
        }
        
        // Resize to standard badge size
        let badgeSize = NSSize(width: 16, height: 16)
        let resizedImage = NSImage(size: badgeSize)
        resizedImage.lockFocus()
        img.draw(in: NSRect(origin: .zero, size: badgeSize),
                 from: NSRect(origin: .zero, size: img.size),
                 operation: .copy,
                 fraction: 1.0)
        resizedImage.unlockFocus()
        
        // Cache and return
        cache[type.identifier] = resizedImage
        return resizedImage
    }
    
    func icon(forURL url: URL) -> NSImage? {
        // Try to get UTType from URL
        if let vals = try? url.resourceValues(forKeys: [.contentTypeKey]),
           let type = vals.contentType {
            return icon(for: type)
        }
        
        // Fall back to extension-based detection
        if let type = UTType(filenameExtension: url.pathExtension) {
            return icon(for: type)
        }
        
        return nil
    }
    
    func clearCache() {
        cache.removeAll()
    }
}