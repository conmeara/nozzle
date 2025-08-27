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

    // Only show prompt-like files. Inject slash-commands when user typed "/".
    var items: [ContentItem] {
        var base = inner.items
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

        if searchQuery.hasPrefix("/") {
            base.insert(commandItem(title: "/new – New empty prompt", command: .new), at: 0)
            base.insert(commandItem(title: "/add – Save current input as new prompt", command: .add), at: 0)
        }
        return base
    }

    func startMonitoring() { inner.startMonitoring() }
    func stopMonitoring() { inner.stopMonitoring() }
    func refresh() async { await inner.refresh() }

    func search(query: String) -> [ContentItem] {
        // Mirror filtering and slash commands
        let filtered = items.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            ($0.plainText ?? "").localizedCaseInsensitiveContains(query)
        }
        return filtered
    }

    // MARK: - Commands & helpers

    private enum Command { case add, new }

    private func commandItem(title: String, command: Command) -> ContentItem {
        ContentItem(
            id: UUID(),
            title: title,
            timestamp: Date(),
            sourceType: .folder,
            sourceId: id,
            fileURL: nil,
            imageData: nil,
            rtfData: nil,
            htmlData: nil,
            plainText: nil,
            fileIdentity: nil,
            uniformTypeIdentifier: "org.nozzle.command.\(command == .add ? "add" : "new")",
            fileSize: nil,
            isFolder: false,
            depth: 0,
            parentPath: nil
        )
    }

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
            Task { @MainActor in await inner.refresh() }
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
            Task { @MainActor in await inner.refresh() }
            return dest
        } catch {
            NSSound.beep()
            return nil
        }
    }

    func deletePrompt(at url: URL) {
        NSWorkspace.shared.recycle([url]) { _, _ in }
        Task { @MainActor in await inner.refresh() }
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
}
