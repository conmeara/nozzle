import Foundation
import AppKit

struct FileContentExtractor {
    static func extractPlainText(from item: ContentItem) -> String {
        guard let url = item.fileURL else {
            return "No file URL available"
        }
        
        do {
            switch url.pathExtension.lowercased() {
            case "txt", "md", "log", "json", "xml", "yml", "yaml":
                // Plain text files - read directly
                return try String(contentsOf: url, encoding: .utf8)
                
            case "rtf", "rtfd":
                // Rich text files - extract plain text
                if let attributedString = try? NSAttributedString(
                    url: url,
                    options: [:],
                    documentAttributes: nil
                ) {
                    return attributedString.string
                } else {
                    return try String(contentsOf: url, encoding: .utf8)
                }
                
            default:
                // Try to read as plain text
                if let content = try? String(contentsOf: url, encoding: .utf8) {
                    return content
                } else {
                    return "Unable to read file contents"
                }
            }
        } catch {
            return "Error loading file: \(error.localizedDescription)"
        }
    }
}