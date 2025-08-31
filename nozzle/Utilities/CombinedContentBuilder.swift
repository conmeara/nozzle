import Foundation
import AppKit
import UniformTypeIdentifiers

// New, non-actor utility responsible for building combined paste content off the main thread.
enum CombinedContentBuilder {
    /// Build combined formatted content from context, examples, prompt, and chips.
    /// Heavy I/O and formatting work is performed off the main thread.
    static func build(
        context: [ContentItem],
        examples: [ContentItem],
        prompt: String,
        chips: [PromptChip]
    ) async -> (rtf: Data?, html: Data?, plain: String) {
        // Flatten items by expanding folders into textual file descendants
        let flatContext = flattenToText(context)
        let flatExamples = flattenToText(examples)

        // Ordered pieces to assemble
        enum Piece {
            case string(String)
            case chip(URL)
            case item(ContentItem)
        }

        var pieces: [Piece] = []

        if !prompt.isEmpty {
            pieces.append(.string(prompt + "\n"))
        }

        if !chips.isEmpty {
            for (index, chip) in chips.enumerated() {
                pieces.append(.string("<prompt \(index + 1)>\n"))
                pieces.append(.chip(chip.url))
                pieces.append(.string("\n"))
            }
        }

        for item in flatContext {
            pieces.append(.string("<context>\n"))
            pieces.append(.item(item))
            pieces.append(.string("\n</context>\n"))
        }

        for item in flatExamples {
            pieces.append(.string("<example>\n"))
            pieces.append(.item(item))
            pieces.append(.string("\n</example>\n"))
        }

        // Resolve attributed content for .item and .chip pieces in parallel
        let combined = NSMutableAttributedString()
        // Wrap NSAttributedString to cross concurrency boundary safely
        struct _AttrBox: @unchecked Sendable { let value: NSAttributedString }
        var results: [Int: _AttrBox] = [:]

        await withTaskGroup(of: (Int, _AttrBox).self) { group in
            for (idx, piece) in pieces.enumerated() {
                switch piece {
                case .string:
                    // Handled synchronously later
                    break
                case .chip(let url):
                    group.addTask {
                        let attr = attributedFromURL(url)
                        return (idx, _AttrBox(value: attr))
                    }
                case .item(let item):
                    group.addTask {
                        let attr = attributedFromItem(item)
                        return (idx, _AttrBox(value: attr))
                    }
                }
            }

            for await (idx, box) in group {
                results[idx] = box
            }
        }

        // Assemble in-order on a background thread
        for (idx, piece) in pieces.enumerated() {
            switch piece {
            case .string(let s):
                combined.append(NSAttributedString(string: s))
            case .chip, .item:
                if let box = results[idx] {
                    combined.append(box.value)
                }
            }
        }

        // Convert to desired formats
        let plain = combined.string
        let range = NSRange(location: 0, length: combined.length)
        let rtf: Data?
        let html: Data?

        if combined.length > 0 {
            rtf = try? combined.data(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
            html = try? combined.data(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.html])
        } else {
            rtf = nil
            html = nil
        }

        return (rtf: rtf, html: html, plain: plain)
    }

    // MARK: - Helpers (non-actor)

    /// Expand folders and filter to textual items only.
    private static func flattenToText(_ items: [ContentItem]) -> [ContentItem] {
        var result: [ContentItem] = []
        var seen: Set<UUID> = []

        for item in items {
            if item.isFolder {
                for desc in textualDescendants(of: item) {
                    if !seen.contains(desc.id) {
                        seen.insert(desc.id)
                        result.append(desc)
                    }
                }
            } else {
                let textual = (item.sourceType == .folder && item.isText) || item.plainText != nil || item.rtfData != nil || item.htmlData != nil
                if textual, !seen.contains(item.id) {
                    seen.insert(item.id)
                    result.append(item)
                }
            }
        }

        return result
    }

    /// Enumerate textual descendants of a folder item, creating ephemeral ContentItems.
    private static func textualDescendants(of folder: ContentItem) -> [ContentItem] {
        guard folder.isFolder, let baseURL = folder.fileURL else { return [] }
        var results: [ContentItem] = []

        let fm = FileManager.default
        if let enumerator = fm.enumerator(
            at: baseURL,
            includingPropertiesForKeys: [.isDirectoryKey, .contentTypeKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let url as URL in enumerator {
                do {
                    let vals = try url.resourceValues(forKeys: [.isDirectoryKey, .contentTypeKey, .contentModificationDateKey, .fileSizeKey])
                    if vals.isDirectory == true { continue }
                    let type = FileSystemSource.resolvedType(for: url)
                    let isMarkdown = (type?.identifier == "net.daringfireball.markdown" || type?.identifier == "public.markdown" || type?.preferredFilenameExtension == "md")
                    let isTextual = (type?.conforms(to: .text) == true) || type == .rtf || type == .rtfd || type == .html || isMarkdown
                    guard isTextual else { continue }

                    let snap = FileIdentity.snapshot(for: url)
                    let id = FileSystemSource.makeStableUUID(identity: snap.identity, fallbackPath: url.absoluteString)
                    let item = ContentItem(
                        id: id,
                        title: url.lastPathComponent,
                        timestamp: vals.contentModificationDate ?? Date(),
                        sourceType: .folder,
                        sourceId: folder.sourceId,
                        fileURL: url,
                        imageData: nil,
                        rtfData: nil,
                        htmlData: nil,
                        plainText: nil,
                        fileIdentity: snap.identity,
                        uniformTypeIdentifier: type?.identifier,
                        fileSize: vals.fileSize.flatMap(Int64.init),
                        isFolder: false,
                        depth: 0,
                        parentPath: nil,
                        isSelected: false,
                        isVisible: true
                    )
                    results.append(item)
                } catch {
                    continue
                }
            }
        }
        return results
    }

    /// Build attributed string for a chip file URL.
    private static func attributedFromURL(_ url: URL) -> NSAttributedString {
        let type = UTType(filenameExtension: url.pathExtension)
        let (rtf, html, plain) = TextFileFormatter.loadAll(from: url, type: type)

        if let rtf = rtf, let attributed = NSAttributedString(rtf: rtf, documentAttributes: nil) {
            return attributed
        } else if let html = html, let attributed = NSAttributedString(html: html, documentAttributes: nil) {
            return attributed
        } else if !plain.isEmpty {
            return NSAttributedString(string: plain)
        }
        return NSAttributedString(string: "")
    }

    /// Build attributed string for a content item.
    private static func attributedFromItem(_ item: ContentItem) -> NSAttributedString {
        // File-backed text from folders: load lazily from disk
        if item.sourceType == .folder && item.isText, let url = item.fileURL {
            let (rtf, html, plain) = TextFileFormatter.loadAll(from: url, type: item.fileUTType)
            if let rtf = rtf, let attributed = NSAttributedString(rtf: rtf, documentAttributes: nil) {
                return attributed
            } else if let html = html, let attributed = NSAttributedString(html: html, documentAttributes: nil) {
                return attributed
            } else if !plain.isEmpty {
                return NSAttributedString(string: plain)
            }
            return NSAttributedString(string: "")
        }

        // Clipboard or already-loaded items
        if let rtf = item.rtfData, let attributed = NSAttributedString(rtf: rtf, documentAttributes: nil) {
            return attributed
        }
        if let html = item.htmlData, let attributed = NSAttributedString(html: html, documentAttributes: nil) {
            return attributed
        }
        if let text = item.plainText {
            return NSAttributedString(string: text)
        }
        return NSAttributedString(string: "")
    }
}
