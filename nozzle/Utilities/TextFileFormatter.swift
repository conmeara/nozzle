import Foundation
import UniformTypeIdentifiers
import AppKit

enum TextFileFormatter {
    
    static func loadAll(from url: URL, type: UTType?) -> (rtf: Data?, html: Data?, plain: String) {
        // Handle RTF files
        if type?.conforms(to: .rtf) == true || type?.conforms(to: .rtfd) == true {
            guard let data = try? Data(contentsOf: url),
                  let nsAttributed = NSAttributedString(rtf: data, documentAttributes: nil) else {
                return (nil, nil, "")
            }
            
            let rtfData = data
            let htmlData = try? nsAttributed.htmlData()
            let plainText = nsAttributed.string
            
            return (rtfData, htmlData, plainText)
        }
        
        // Handle plain text and markdown
        guard let rawText = try? String(contentsOf: url, encoding: .utf8) else {
            return (nil, nil, "")
        }
        
        // Check if it's markdown
        if type?.identifier == "net.daringfireball.markdown" ||
           type?.identifier == "public.markdown" ||
           url.pathExtension.lowercased() == "md" {
            // Try to render markdown to attributed string
            if let attributedString = try? AttributedString(markdown: rawText, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                let nsAttributed = NSAttributedString(attributedString)
                let rtfData = try? nsAttributed.rtfData()
                let htmlData = try? nsAttributed.htmlData()
                return (rtfData, htmlData, rawText)
            }
        }
        
        // Plain text: create basic attributed string
        let nsAttributed = NSAttributedString(string: rawText)
        let rtfData = try? nsAttributed.rtfData()
        let htmlData = try? nsAttributed.htmlData()
        
        return (rtfData, htmlData, rawText)
    }
    
    static func loadPlainText(from url: URL) -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }
    
    static func loadAttributedText(from url: URL, type: UTType?) -> NSAttributedString? {
        if type?.conforms(to: .rtf) == true || type?.conforms(to: .rtfd) == true {
            guard let data = try? Data(contentsOf: url) else { return nil }
            return NSAttributedString(rtf: data, documentAttributes: nil)
        }
        
        guard let plainText = loadPlainText(from: url) else { return nil }
        
        // Try markdown rendering if applicable
        if type?.identifier == "net.daringfireball.markdown" ||
           type?.identifier == "public.markdown" ||
           url.pathExtension.lowercased() == "md" {
            if let attributedString = try? AttributedString(markdown: plainText, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                return NSAttributedString(attributedString)
            }
        }
        
        return NSAttributedString(string: plainText)
    }
    
    static func save(string: String, to url: URL, type: UTType?) throws {
        // Pick an encoding/format based on UTType; default to UTF-8 plain text
        switch type {
        case .some(let t) where t == .rtf || t == .rtfd:
            // For now, write plain string as RTF with default attributes; later: round-trip RTF if you keep NSAttributedString
            let attr = NSAttributedString(string: string)
            if let data = try? attr.data(from: NSRange(location: 0, length: attr.length),
                                         documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
                try data.write(to: url, options: .atomic)
            } else {
                try string.write(to: url, atomically: true, encoding: .utf8)
            }
            
        case .some(let t) where t == .html:
            let esc = string.replacingOccurrences(of: "&", with: "&amp;")
                            .replacingOccurrences(of: "<", with: "&lt;")
                            .replacingOccurrences(of: ">", with: "&gt;")
            let html = "<pre>\(esc)</pre>"
            try Data(html.utf8).write(to: url, options: .atomic)
            
        default:
            try string.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - NSAttributedString Extensions

private extension NSAttributedString {
    func rtfData() throws -> Data {
        try data(from: NSRange(location: 0, length: length),
                 documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    }
    
    func htmlData() throws -> Data {
        try data(from: NSRange(location: 0, length: length),
                 documentAttributes: [.documentType: NSAttributedString.DocumentType.html])
    }
}