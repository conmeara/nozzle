import SwiftUI
import UniformTypeIdentifiers
import Foundation

// Inline file presenter to avoid additional dependencies
private class InlineFilePresenter: NSObject, NSFilePresenter {
    let presentedItemURL: URL?
    let presentedItemOperationQueue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1
        return q
    }()

    var onChange: (() -> Void)?

    init(url: URL, onChange: (() -> Void)? = nil) {
        self.presentedItemURL = url
        self.onChange = onChange
        super.init()
    }

    func presentedItemDidChange() {
        onChange?()
    }
}

struct PromptEditorView: View {
    let item: ContentItem   // must be a file-backed text item
    
    @State private var text: String = ""
    @State private var presenter: InlineFilePresenter?
    @State private var saveWork: DispatchWorkItem?
    
    @Environment(ContentManager.self) private var contentManager
    
    var body: some View {
        TextEditor(text: $text)
            .font(.system(.body, design: .monospaced))
            .padding(.horizontal, 8)
            .onAppear {
                load()
                setupPresenter()
            }
            .onChange(of: text) { _ in scheduleSave() }
            .onDisappear { saveImmediately() }
    }
    
    private func load() {
        guard let url = item.fileURL else { return }
        if let content = TextFileFormatter.loadPlainText(from: url) {
            // Avoid resetting the cursor position on every external change if unchanged
            if content != text { text = content }
        }
    }
    
    private func setupPresenter() {
        guard presenter == nil, let url = item.fileURL else { return }
        let p = InlineFilePresenter(url: url) {
            DispatchQueue.main.async {
                self.load()
            }
        }
        NSFileCoordinator.addFilePresenter(p)
        presenter = p
    }
    
    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { self.saveImmediately() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }
    
    private func saveImmediately() {
        guard let url = item.fileURL else { return }
        
        // Suspend resort while we write so the list doesn't jump due to mod date
        if let fs = contentManager.sources[item.sourceId] as? FileSystemSource {
            fs.suspendResort(for: item.id, enabled: true)
        }
        
        let coord = NSFileCoordinator(filePresenter: presenter)
        var error: NSError?
        coord.coordinate(writingItemAt: url, options: .forReplacing, error: &error) { writeURL in
            try? text.write(to: writeURL, atomically: true, encoding: .utf8)
        }
        
        if let fs = contentManager.sources[item.sourceId] as? FileSystemSource {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                fs.suspendResort(for: item.id, enabled: false)
            }
        }
    }
}