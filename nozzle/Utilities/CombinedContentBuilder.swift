import Foundation
import AppKit
import UniformTypeIdentifiers

// New, non-actor utility responsible for building combined paste content off the main thread.
enum CombinedContentBuilder {
    /// Build combined plain-text content from context, examples, prompt, and chips.
    /// Heavy disk I/O is performed off the main thread.
    static func build(
        context: [ContentItem],
        examples: [ContentItem],
        prompt: String,
        chips: [PromptChip]
    ) async -> String {
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

        // Resolve plain text for .item and .chip pieces in parallel
        struct _PlainBox: @unchecked Sendable { let value: String }
        var results: [Int: _PlainBox] = [:]

        await withTaskGroup(of: (Int, _PlainBox).self) { group in
            for (idx, piece) in pieces.enumerated() {
                switch piece {
                case .string:
                    break
                case .chip(let url):
                    group.addTask {
                        let s = plainFromURL(url)
                        return (idx, _PlainBox(value: s))
                    }
                case .item(let item):
                    group.addTask {
                        let s = plainFromItem(item)
                        return (idx, _PlainBox(value: s))
                    }
                }
            }

            for await (idx, box) in group {
                results[idx] = box
            }
        }

        // Assemble in-order on a background thread
        var combined = ""
        for (idx, piece) in pieces.enumerated() {
            switch piece {
            case .string(let s):
                combined.append(s)
            case .chip, .item:
                if let box = results[idx] {
                    combined.append(box.value)
                }
            }
        }

        return combined
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

    /// Extract plain text from a chip file URL.
    private static func plainFromURL(_ url: URL) -> String {
        let type = UTType(filenameExtension: url.pathExtension)

        // RTF/RTFD → decode attributed and take .string
        if type?.conforms(to: .rtf) == true || type?.conforms(to: .rtfd) == true {
            if let data = try? Data(contentsOf: url),
               let attr = NSAttributedString(rtf: data, documentAttributes: nil) {
                return attr.string
            }
            return ""
        }

        // HTML → decode attributed and take .string
        if type == .html {
            if let data = try? Data(contentsOf: url),
               let attr = NSAttributedString(html: data, documentAttributes: nil) {
                return attr.string
            }
            return ""
        }

        // Markdown or any other textual type → read as UTF-8 string
        if let s = try? String(contentsOf: url, encoding: .utf8) {
            return s
        }
        return ""
    }

    /// Extract plain text from a content item.
    private static func plainFromItem(_ item: ContentItem) -> String {
        // File-backed text from folders: load lazily from disk
        if item.sourceType == .folder && item.isText, let url = item.fileURL {
            return plainFromURL(url)
        }

        // Clipboard or already-loaded items
        if let text = item.plainText {
            return text
        }
        if let rtf = item.rtfData, let attr = NSAttributedString(rtf: rtf, documentAttributes: nil) {
            return attr.string
        }
        if let html = item.htmlData, let attr = NSAttributedString(html: html, documentAttributes: nil) {
            return attr.string
        }
        return ""
    }
}
