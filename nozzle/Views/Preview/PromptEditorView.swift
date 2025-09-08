import SwiftUI
import UniformTypeIdentifiers
import Foundation

// Inline file presenter to avoid additional dependencies
private class InlineFilePresenter: NSObject, NSFilePresenter {
    // Must be mutable so we can follow file moves/renames
    var presentedItemURL: URL?
    let presentedItemOperationQueue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1
        return q
    }()

    var onChange: (() -> Void)?
    var onMove: ((URL) -> Void)?

    init(url: URL, onChange: (() -> Void)? = nil) {
        self.presentedItemURL = url
        self.onChange = onChange
        super.init()
    }

    func presentedItemDidChange() {
        onChange?()
    }

    // Follow file when it’s renamed or moved
    func presentedItemDidMove(to newURL: URL) {
        presentedItemURL = newURL
        onMove?(newURL)
    }
}

struct PromptEditorView: View {
    let item: ContentItem   // must be a file-backed text item
    
    @State private var text: String = ""
    @State private var presenter: InlineFilePresenter?
    @State private var saveWork: DispatchWorkItem?
    // Track the currently loaded file explicitly to avoid writing to the wrong file
    @State private var currentItemId: UUID?
    @State private var currentFileURL: URL?
    @State private var isSaving: Bool = false
    @State private var isDirty: Bool = false
    @State private var hasExternalChange: Bool = false
    @State private var isEditing: Bool = false
    @FocusState private var editorFocused: Bool
    // Grace period after our own save to ignore self-change notifications
    @State private var ignoreChangesUntil: Date? = nil
    // Enhancement state
    @State private var isEnhancing: Bool = false
    
    @Environment(ContentManager.self) private var contentManager
    
    var body: some View {
        VStack(spacing: 0) {
            if hasExternalChange {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                    Text("File changed on disk")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Reload") {
                        // Discard local edits and reload from disk
                        hasExternalChange = false
                        isDirty = false
                        load()
                    }
                    Button("Keep Mine") {
                        // Overwrite disk with current text
                        hasExternalChange = false
                        saveImmediately()
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            }

            if isEditing {
                // Editing view with enhance button
                HStack(alignment: .top, spacing: 0) {
                    TextEditor(text: $text)
                        .id(currentItemId)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .padding()
                        .focused($editorFocused)
                        .onChange(of: editorFocused) { _, focused in
                            if !focused {
                                // Save and exit edit mode when focus leaves editor
                                saveImmediately()
                                isEditing = false
                            }
                        }
                    
                    // Enhance button in the top right corner while editing
                    VStack {
                        Button(action: {
                            guard !isEnhancing else { return }
                            Task {
                                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                                isEnhancing = true
                                do {
                                    let enhanced = try await PromptEnhancer.shared.enhance(text)
                                    text = enhanced
                                    isDirty = true
                                    scheduleSave()
                                } catch {
                                    // Handle error - could show alert or tooltip
                                    print("Enhancement error: \(error.localizedDescription)")
                                }
                                isEnhancing = false
                            }
                        }) {
                            ZStack {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14))
                                    .foregroundColor(isEnhancing ? .purple : .secondary)
                                
                                if isEnhancing {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 14))
                                        .foregroundColor(.purple)
                                        .symbolEffect(.pulse.byLayer, options: .repeating, isActive: isEnhancing)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(isEnhancing ? "Enhancing..." : "Enhance prompt with AI")
                        .disabled(text.isEmpty)
                        .padding(.top, 12)
                        .padding(.trailing, 12)
                        
                        Spacer()
                    }
                }
            } else {
                // Read-only preview matching PlainTextPreview style
                ZStack {
                    ScrollView {
                        Text(text)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Full-area invisible tap target to ensure single-click enters edit mode
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isEditing = true
                            DispatchQueue.main.async { editorFocused = true }
                        }
                        .allowsHitTesting(true)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .previewSurfaceStyle()
        // Exit edit mode when pointer leaves the preview pane (user hovers back to list)
        .onHover { inside in
            if isEditing && !inside {
                saveImmediately()
                isEditing = false
            }
        }
            .onAppear {
                // Initialize tracking for the first item
                currentItemId = item.id
                currentFileURL = item.fileURL
                load()
                setupPresenter()
            }
            .onChange(of: text) { _, _ in
                if isEditing {
                    isDirty = true
                    scheduleSave()
                }
            }
            .onChange(of: item.id) { _, _ in
                // Save and tear down previous bindings before switching
                saveWork?.cancel()
                // Only save to the previous file if its URL hasn't just changed (rename case)
                if item.fileURL == currentFileURL {
                    saveImmediately() // save to previous file via currentFileURL
                }
                removePresenter()

                // Reset state and switch to the new item
                currentItemId = item.id
                currentFileURL = item.fileURL
                hasExternalChange = false
                isDirty = false
                isEditing = false
                load()
                setupPresenter()
            }
            .onChange(of: item.fileURL) { _, _ in
                // Handle file renames/moves that keep the same identity/UUID
                // Important: do NOT save to the old URL here, as that would resurrect the old filename.
                saveWork?.cancel()
                removePresenter()

                currentFileURL = item.fileURL
                hasExternalChange = false
                isDirty = false
                isEditing = false
                load()
                setupPresenter()
            }
            .onDisappear {
                saveWork?.cancel()
                saveImmediately()
                removePresenter()
            }
            // Guard against rename races: when a global rename commit happens, pause reactions briefly
            // Note: rename commits are coordinated elsewhere; no special pause needed here
    }
    
    private func load() {
        guard let url = currentFileURL ?? item.fileURL else { return }
        // Coordinate read to avoid racing with writes
        let coord = NSFileCoordinator(filePresenter: presenter)
        var error: NSError?
        var loaded: String?
        coord.coordinate(readingItemAt: url, options: [], error: &error) { readURL in
            loaded = try? String(contentsOf: readURL, encoding: .utf8)
        }
        if let content = loaded {
            // Avoid resetting the cursor position on every external change if unchanged
            if content != text { text = content }
        }
    }
    
    private func setupPresenter() {
        guard presenter == nil, let url = currentFileURL ?? item.fileURL else { return }
        let p = InlineFilePresenter(url: url) {
            // Always handle on main for state safety
            DispatchQueue.main.async {
                // Ignore notifications during/shortly after our own saves
                if isSaving { return }
                if let until = ignoreChangesUntil, Date() < until { return }

                // If the user has unsaved edits, show conflict banner instead of clobbering
                if isDirty {
                    hasExternalChange = true
                    return
                }
                self.load()
            }
        }
        p.onMove = { newURL in
            DispatchQueue.main.async {
                // Point the editor at the new file path so future saves don’t resurrect the old name
                self.currentFileURL = newURL
                // Grace period to ignore our own subsequent change notifications
                self.ignoreChangesUntil = Date().addingTimeInterval(1.0)
            }
        }
        NSFileCoordinator.addFilePresenter(p)
        presenter = p
    }
    
    private func removePresenter() {
        if let p = presenter {
            NSFileCoordinator.removeFilePresenter(p)
        }
        presenter = nil
    }
    
    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { self.saveImmediately() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }
    
    private func saveImmediately() {
        // Always save to the file that is currently loaded in the editor
        guard let url = currentFileURL ?? item.fileURL else { return }
        if !isDirty { return }
        
        // Suspend resort while we write so the list doesn't jump due to mod date
        if let fs = contentManager.sources[item.sourceId] as? FileSystemSource {
            fs.suspendResort(for: currentItemId ?? item.id, enabled: true)
        }
        
        isSaving = true
        let coord = NSFileCoordinator(filePresenter: presenter)
        var error: NSError?
        coord.coordinate(writingItemAt: url, options: .forReplacing, error: &error) { writeURL in
            try? text.write(to: writeURL, atomically: true, encoding: .utf8)
        }
        // Ignore self-triggered change notifications for a short grace period
        ignoreChangesUntil = Date().addingTimeInterval(1.0)
        isSaving = false
        isDirty = false
        
        if let fs = contentManager.sources[item.sourceId] as? FileSystemSource {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                fs.suspendResort(for: currentItemId ?? item.id, enabled: false)
            }
        }
    }
}
