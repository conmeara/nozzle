import AppKit
import Observation
import UniformTypeIdentifiers
import Defaults

@Observable @MainActor
final class PromptsSource: ContentSource {
    let id = "prompts"
    let name = "Prompts"
    let icon = NSImage(systemSymbolName: "text.quote", accessibilityDescription: "Prompts")!
    let type: ContentSourceType = .folder // reuse existing universal UI

    private(set) var folderURL: URL
    private let inner: FileSystemSource

    // Forwarded state
    var isMonitoring: Bool { inner.isMonitoring }
    var searchQuery: String {
        get { inner.searchQuery }
        set { inner.searchQuery = newValue }
    }

    init(folderURL: URL) {
        self.folderURL = folderURL
        self.inner = FileSystemSource(folderURL: folderURL)
    }

    // Only show prompt-like files.
    var items: [ContentItem] {
        return inner.items
            .filter { !$0.isFolder }
            .filter { $0.isText || $0.isMarkdown || $0.uniformTypeIdentifier == UTType.plainText.identifier }
            .map { item in
                // Map to normalize sourceId to "prompts" for proper routing
                ContentItem(
                    id: item.id,
                    title: item.title,
                    timestamp: item.timestamp,
                    sourceType: item.sourceType,
                    sourceId: "prompts", // Normalize to "prompts" for preview routing
                    fileURL: item.fileURL,
                    imageData: item.imageData,
                    rtfData: item.rtfData,
                    htmlData: item.htmlData,
                    plainText: item.plainText,
                    fileIdentity: item.fileIdentity,
                    uniformTypeIdentifier: item.uniformTypeIdentifier,
                    fileSize: item.fileSize,
                    isFolder: item.isFolder,
                    depth: item.depth,
                    parentPath: item.parentPath,
                    isSelected: item.isSelected,
                    isVisible: item.isVisible
                )
            }
    }

    func startMonitoring() { inner.startMonitoring() }
    func stopMonitoring() { inner.stopMonitoring() }
    func refresh() async { await inner.refresh() }

    func search(query: String) -> [ContentItem] {
        // Filter items based on title and content
        let filtered = items.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            ($0.plainText ?? "").localizedCaseInsensitiveContains(query)
        }
        return filtered
    }

    // MARK: - Helpers

    static func defaultFolder() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Nozzle/Prompts", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    @discardableResult
    func createNewPrompt(named suggested: String? = nil, initialContents: String = "") -> URL? {
        let ext = Defaults[.promptsFileExtension]
        let base = (suggested?.isEmpty == false ? suggested! : "Untitled")
        let url = uniqueURL(basename: base, ext: ext)
        do {
            try TextFileFormatter.save(string: initialContents, to: url, type: .plainText)
            // Compute stable id deterministically now to avoid racing the refresh
            let snap = FileIdentity.snapshot(for: url)
            let id = FileSystemSource.makeStableUUID(identity: snap.identity, fallbackPath: url.absoluteString)
            Task { @MainActor in
                ContentManager.shared.markDecoratorsNeedRefresh(for: "prompts")
                await inner.refresh()
                ContentManager.shared.requestRename(for: id)
            }
            return url
        } catch {
            NSSound.beep()
            return nil
        }
    }

    @discardableResult
    func duplicatePrompt(at url: URL) -> URL? {
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension.isEmpty ? Defaults[.promptsFileExtension] : url.pathExtension
        let dest = uniqueURL(basename: "\(base) copy", ext: ext)
        do {
            try FileManager.default.copyItem(at: url, to: dest)
            Task { @MainActor in 
                ContentManager.shared.markDecoratorsNeedRefresh(for: "prompts")
                await inner.refresh() 
            }
            return dest
        } catch {
            NSSound.beep()
            return nil
        }
    }

    func deletePrompt(at url: URL) {
        NSWorkspace.shared.recycle([url]) { _, _ in
            Task { @MainActor in
                ContentManager.shared.markDecoratorsNeedRefresh(for: "prompts")
                await self.inner.refresh()
            }
        }
    }

    @discardableResult
    func renamePrompt(at oldURL: URL, to newDisplayName: String) -> URL? {
        let fm = FileManager.default
        let ext = oldURL.pathExtension.isEmpty ? Defaults[.promptsFileExtension] : oldURL.pathExtension
        // Sanitize base name and strip extension if user typed one
        var base = newDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if base.hasSuffix(".\(ext)") {
            base = String(base.dropLast(ext.count + 1))
        }
        base = sanitizeFileName(base)
        guard !base.isEmpty else { NSSound.beep(); return nil }

        let newURL = folderURL.appendingPathComponent(base).appendingPathExtension(ext)

        // No-op
        if newURL == oldURL { return newURL }

        // Conflict
        if fm.fileExists(atPath: newURL.path) {
            NSSound.beep(); return nil
        }

        do {
            let currentBase = oldURL.deletingPathExtension().lastPathComponent
            if currentBase.caseInsensitiveCompare(base) == .orderedSame {
                // Case-only change on case-insensitive volumes: hop via a temp name
                let tmp = uniqueURL(basename: "\(base)-tmp-\(UUID().uuidString.prefix(6))", ext: ext)
                let coord = NSFileCoordinator()
                var err: NSError?
                // Move old -> tmp
                coord.coordinate(writingItemAt: oldURL, options: .forMoving, writingItemAt: tmp, options: .forReplacing, error: &err) { src, dst in
                    try? fm.moveItem(at: src, to: dst)
                }
                if err == nil {
                    // Move tmp -> new
                    coord.coordinate(writingItemAt: tmp, options: .forMoving, writingItemAt: newURL, options: .forReplacing, error: &err) { src, dst in
                        try? fm.moveItem(at: src, to: dst)
                    }
                }
                if err != nil { throw err! }
            } else {
                // Coordinated move so NSFilePresenter receives didMove
                let coord = NSFileCoordinator()
                var err: NSError?
                coord.coordinate(writingItemAt: oldURL, options: .forMoving, writingItemAt: newURL, options: .forReplacing, error: &err) { src, dst in
                    try? fm.moveItem(at: src, to: dst)
                }
                if let e = err { throw e }
            }
            
            // Update UI and prompt chips
            Task { @MainActor in
                // First update the prompt chip URL immediately
                AppState.shared.updatePromptChipURL(from: oldURL, to: newURL)

                // Mark decorators as needing refresh before refreshing the file list
                ContentManager.shared.markDecoratorsNeedRefresh(for: "prompts")

                // Then refresh the file list to show the new name
                await self.inner.refresh()

                // Keep focus on the renamed item
                if let renamedItem = self.items.first(where: { $0.fileURL == newURL }) {
                    ContentManager.shared.focus(renamedItem.id)
                }

                // Register undo for the rename
                let oldBaseName = oldURL.deletingPathExtension().lastPathComponent
                AppState.shared.undoManager.registerUndo(withTarget: self) { target in
                    _ = target.renamePrompt(at: newURL, to: oldBaseName)
                }
                AppState.shared.undoManager.setActionName("Rename")
            }
            return newURL
        } catch {
            NSSound.beep()
            return nil
        }
    }

    func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func applyPrompt(at url: URL) {
        if let text = TextFileFormatter.loadPlainText(from: url) {
            AppState.shared.promptText = text
            AppState.shared.updateFooterItemVisibility()
        }
    }

    func addPromptToInput(at url: URL) {
        if let text = TextFileFormatter.loadPlainText(from: url) {
            AppState.shared.appendToInput(text)
        }
    }

    // MARK: - Utils

    private func uniqueURL(basename: String, ext: String) -> URL {
        var candidate = folderURL.appendingPathComponent("\(basename).\(ext)")
        var idx = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folderURL.appendingPathComponent("\(basename) \(idx).\(ext)")
            idx += 1
        }
        return candidate
    }

    private func sanitizeFileName(_ name: String) -> String {
        // Remove disallowed characters and collapse whitespace
        let bad = CharacterSet(charactersIn: "/:")
            .union(.newlines)
            .union(.controlCharacters)
        let cleaned = name.components(separatedBy: bad).joined(separator: " ")
        return cleaned.replacingOccurrences(of: #"[\s]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
