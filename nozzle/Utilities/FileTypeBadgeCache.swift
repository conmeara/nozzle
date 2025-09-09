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
        
        // Get system icon for content type (modern API)
        let img: NSImage = NSWorkspace.shared.icon(for: type)
        
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
        // Try to get UTType from URL (content-type based badge)
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
