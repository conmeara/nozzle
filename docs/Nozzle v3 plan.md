## Overview

This document outlines the architectural transformation of nozzle from a clipboard-only manager to a unified multi-source content aggregation platform. The evolution maintains backward compatibility while introducing a scalable foundation for unlimited content sources.

### Transformation Goals
- **Unified UI**: All sources use identical interface patterns
- **Scalable Sources**: Easy addition of new content types
- **Cross-Source Operations**: Selections and operations across multiple sources
- **Maintained Performance**: No degradation of existing clipboard functionality
- **Future-Ready**: Architecture prepared for Notes, Screenshots, and other sources

Below is a **senior‑level implementation plan** to evolve _nozzle_ from a clipboard‑only manager to a **multi‑source content aggregator** while keeping the simplest path for Phase 1 and leaving clean seams for Phase 2. The plan is organized as a sequence of concrete work items. For each change I call out **what file(s)** to touch, **where** in those files, **what to add/modify**, **why**, and **impacts/side‑effects**. Short code snippets illustrate interfaces and patterns, not full implementations.

> Target stack: **Swift 6**, macOS “26 Tahoe”, SwiftUI + Observation.  
> Constraints: **preserve current clipboard behavior and performance**; add sources incrementally; reuse existing UI row; avoid invasive changes to History* in Phase 1.

---

## PHASE 0 — Scaffolding the multi‑source seams

### 0.1 Add core protocols and shared models

**Add**

```
nozzle/Protocols/ContentSource.swift
nozzle/Protocols/ContentItem.swift
nozzle/Protocols/ContentSourceType.swift
```

**ContentSourceType.swift**

```swift
public enum ContentSourceType: String, Sendable, CaseIterable {
  case clipboard, folder
  // future: notes, screenshots, cloud, …
}
```

**ContentItem.swift** (unified item model; Phase 1 keeps this lightweight)

```swift
import AppKit

public struct ContentItem: Identifiable, Hashable, Sendable {
  public let id: UUID
  public let title: String
  public let timestamp: Date
  public let sourceType: ContentSourceType
  public let sourceId: String

  // Optional format-specific data (future-safe)
  public let fileURL: URL?
  public let imageData: Data?
  public let rtfData: Data?
  public let htmlData: Data?
  public let plainText: String?

  // UI state (kept here so Universal views don’t mutate external state)
  public var isSelected: Bool = false
  public var isVisible: Bool = true
}
```

**ContentSource.swift**

```swift
import AppKit

@MainActor
public protocol ContentSource: AnyObject {
  var id: String { get }
  var name: String { get }
  var icon: NSImage { get }
  var type: ContentSourceType { get }
  var isMonitoring: Bool { get }
  var items: [ContentItem] { get }       // stable order, newest first
  var searchQuery: String { get set }    // each source may filter differently

  func startMonitoring()
  func stopMonitoring()
  func refresh() async
  func search(query: String) -> [ContentItem]
}
```

**Why**

- Protocol‑oriented seams for all sources; keeps UI and coordinator agnostic of source internals (matching the architecture doc).
    
- `searchQuery` lives per‑source for Phase 1 simplicity.
    
- `ContentItem` keeps optional payload fields and UI flags but **does not** force a single storage schema.
    

**Impacts**

- None on existing clipboard flow yet.
    
- These files introduce _no_ compile‑time coupling to current History types.
    

---

## PHASE 1 — Minimal, low‑risk integration (Clipboard + Folder)

### 1.1 Introduce a central coordinator (`ContentManager`)

**Add**

```
nozzle/Observables/ContentManager.swift
```

**ContentManager.swift**

```swift
import AppKit
import Observation

@Observable @MainActor
final class ContentManager {
  static let shared = ContentManager()

  private(set) var sources: [String: any ContentSource] = [:]
  private(set) var orderedSourceIds: [String] = []
  var activeSourceId: String = "clipboard"   // default tab
  var nonClipboardSelection: Set<UUID> = []  // Phase 1: selection outside clipboard

  // Computed views
  var activeItems: [ContentItem] {
    guard let src = sources[activeSourceId] else { return [] }
    return src.items
  }

  // Registration
  func registerSource<T: ContentSource>(_ source: T) {
    sources[source.id] = source
    if !orderedSourceIds.contains(source.id) { orderedSourceIds.append(source.id) }
  }

  // Lookup
  func getAllSources() -> [any ContentSource] {
    orderedSourceIds.compactMap { sources[$0] }
  }

  func getItems(for sourceId: String) -> [ContentItem] {
    sources[sourceId]?.items ?? []
  }

  // Search
  func searchAcrossAllSources(query: String) -> [ContentItem] {
    sources.values.flatMap { $0.search(query: query) }
  }

  // Phase 2 placeholder
  // var selectedItemIds: Set<UUID> = []
}
```

**Why**

- A single observable hub for sources and tab state aligns with your plan.
    
- **Phase 1**: keep clipboard selection as‑is (in `History`); track selection only for non‑clipboard sources here.
    

**Impacts**

- New environment object to inject into UI (ContentView/AppDelegate changes below).
    

---

### 1.2 Wrap existing clipboard into a `ContentSource` adapter

**Add**

```
nozzle/Sources/ClipboardSource.swift
```

**ClipboardSource.swift** (adapter)

```swift
import AppKit

@Observable @MainActor
final class ClipboardSource: ContentSource {
  let id = "clipboard"
  let name = "Clipboard"
  let icon = NSImage(named: .clipboard)!
  let type: ContentSourceType = .clipboard

  private let history: History = History.shared      // existing model
  var isMonitoring: Bool { true }                    // handled by Clipboard itself
  var searchQuery: String {
    get { history.searchQuery }
    set { history.searchQuery = newValue }          // leverage existing search
  }

  var items: [ContentItem] {
    // Map HistoryItemDecorator -> ContentItem
    history.items.map {
      ContentItem(
        id: $0.id,
        title: $0.title,
        timestamp: $0.item.lastCopiedAt,
        sourceType: .clipboard,
        sourceId: id,
        fileURL: $0.item.fileURLs.first,
        imageData: $0.item.imageData,
        rtfData: $0.item.rtfData,
        htmlData: $0.item.htmlData,
        plainText: $0.item.text,
        isSelected: $0.isSelected,
        isVisible: $0.isVisible
      )
    }
  }

  func startMonitoring() {}
  func stopMonitoring() {}
  func refresh() async {}
  func search(query: String) -> [ContentItem] { items.filter { $0.title.localizedCaseInsensitiveContains(query) } }
}
```

**Why**

- Zero risk to clipboard logic: simply reads from `History` (existing `History` and `HistoryItemDecorator` drive behavior and UI for that tab).
    
- Allows **dynamic tabs** to include Clipboard seamlessly.
    

**Impacts**

- None on current selection paths for clipboard UI (`HistoryListView`, `HistoryItemView`, `AppState` continue to work).
    
- Keep this source read‑only; all mutating actions still go through existing paths (copy/paste/pin).
    

References to current clipboard flow: `History` and `HistoryItemDecorator` drive item state and selection (see current classes in the repo) — this adapter reads them without rewriting their internals.

---

### 1.3 Introduce a basic folder source (`FileSystemSource`) without FSEvents (yet)

**Add**

```
nozzle/Sources/FileSystemSource.swift
nozzle/Utils/SecurityScopedBookmarks.swift
```

**FileSystemSource.swift** (Phase 1: async scanning; stable IDs)

```swift
import AppKit
import UniformTypeIdentifiers

@Observable @MainActor
final class FileSystemSource: ContentSource {
  let id: String
  let name: String
  let icon: NSImage
  let type: ContentSourceType = .folder
  private let folderURL: URL
  private var cachedItems: [ContentItem] = []

  var isMonitoring: Bool = false
  var searchQuery: String = ""

  init(folderURL: URL) {
    self.folderURL = folderURL
    self.id = "folder:\(folderURL.path)"
    self.name = folderURL.lastPathComponent
    self.icon = NSWorkspace.shared.icon(forFile: folderURL.path)
  }

  var items: [ContentItem] {
    if searchQuery.isEmpty { return cachedItems }
    return search(query: searchQuery)
  }

  func startMonitoring() { /* Phase 2 (FSEvents) */ }
  func stopMonitoring()  { /* Phase 2 */ }

  func refresh() async {
    // Off-main scanning; update on MainActor
    let urls = try? FileManager.default.contentsOfDirectory(
      at: folderURL,
      includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
      options: [.skipsHiddenFiles]
    )
    let dateProvider: (URL) -> Date = { url in
      (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }
    let items = (urls ?? [])
      .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) != true }
      .map { url -> ContentItem in
        let ts = dateProvider(url)
        let id = UUID(uuidString: UUIDv5.namespaceURL.uuidString(with: url.absoluteString + "\(ts.timeIntervalSince1970)")) ?? UUID()
        return ContentItem(
          id: id, title: url.lastPathComponent, timestamp: ts,
          sourceType: .folder, sourceId: self.id,
          fileURL: url, imageData: nil, rtfData: nil, htmlData: nil, plainText: url.path
        )
      }
      .sorted { $0.timestamp > $1.timestamp }
    await MainActor.run { self.cachedItems = items }
  }

  func search(query: String) -> [ContentItem] {
    cachedItems.filter {
      $0.title.localizedCaseInsensitiveContains(query) ||
      ($0.plainText ?? "").localizedCaseInsensitiveContains(query)
    }
  }
}
```

> **Note**: `UUIDv5.namespaceURL.uuidString(with:)` in the snippet is pseudocode for “derive a stable UUID from URL + modTime”; implement a tiny utility for stable IDs or use hashing (e.g., SHA256 → UUID).

**SecurityScopedBookmarks.swift**

- Utility to create/store/retrieve **security‑scoped bookmarks** for user‑picked folders (in App Sandbox).
    
- Exposes:
    
    ```swift
    enum Bookmarks {
      static func store(url: URL) throws
      static func resolveAll() -> [URL]
    }
    ```
    

**Why**

- Start with the simplest: periodic/manual `refresh()`, no FSEvents.
    
- Stable ID composition prevents list flicker and preserves selection after refresh.
    

**Impacts**

- **Entitlements** needed (see §1.7).
    
- New “Add Folder” UX path will create and register instances of `FileSystemSource`.
    

---

### 1.4 Add a thin universal decorator only for non‑clipboard items (Phase 1)

**Add**

```
nozzle/Observables/UniversalItemDecorator.swift
```

**UniversalItemDecorator.swift**

```swift
import AppKit
import Observation

@Observable @MainActor
final class UniversalItemDecorator: Identifiable, Hashable {
  let id: UUID
  private(set) var base: ContentItem
  let sourceId: String

  // Derived UI
  var title: String { base.title }
  var isSelected: Bool { didSet { base.isSelected = isSelected } }
  var isVisible: Bool  { didSet { base.isVisible = isVisible } }

  init(_ item: ContentItem) {
    self.id = item.id
    self.base = item
    self.sourceId = item.sourceId
    self.isSelected = item.isSelected
    self.isVisible = item.isVisible
  }

  nonisolated func hash(into h: inout Hasher) { h.combine(id) }

  // Cross-source common action
  func copyToClipboard() {
    if let url = base.fileURL {
      let pb = NSPasteboard.general
      pb.clearContents(); pb.writeObjects([url as NSURL])
    } else if let rtf = base.rtfData ?? base.htmlData {
      let pb = NSPasteboard.general
      pb.clearContents()
      if let rtf { pb.setData(rtf, forType: .rtf) }
      if let html = base.htmlData { pb.setData(html, forType: .html) }
      if let text = base.plainText { pb.setString(text, forType: .string) }
    } else if let text = base.plainText {
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(text, forType: .string)
    }
  }
}
```

**Why**

- Non‑clipboard sources need a row model with the same surface as `HistoryItemDecorator` without coupling to History.
    
- Keep just what the universal row needs (title, selected, copy action).
    

**Impacts**

- Clipboard tab **still** uses the existing `HistoryItemView` to avoid risk (Phase 1).
    
- Non‑clipboard tabs use `UniversalItemDecorator` → unified List UI.
    

---

### 1.5 New universal list/view wrapper that reuses the existing row UI

**Add**

```
nozzle/Views/UniversalListView.swift
nozzle/Views/UniversalItemView.swift
```

**UniversalListView.swift**

```swift
import SwiftUI

struct UniversalListView: View {
  let items: [UniversalItemDecorator]   // already adapted
  @Environment(AppState.self) private var appState

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        ForEach(items) { deco in
          UniversalItemView(item: deco)
        }
      }
    }
  }
}
```

**UniversalItemView.swift** (thin shim mapping into `ListItemView` to avoid UI drift)

```swift
import SwiftUI

struct UniversalItemView: View {
  @Bindable var item: UniversalItemDecorator
  @Environment(AppState.self) private var appState

  var body: some View {
    ListItemView(
      id: item.id,
      appIcon: nil,                        // optional: resolve by UTType/app owner later
      image: nil,                          // optional: lightweight thumbs in Phase 2
      accessoryImage: nil,
      attributedTitle: nil,
      shortcuts: [],                       // no numbered shortcuts for file sources in Phase 1
      isSelected: item.isSelected
    ) {
      Text(verbatim: item.title)
    }
    .onTapGesture { location in
      // emulate HistoryItemView behavior: right 60px = copy; else toggle selection
      let isCopy = location.x > 240  // compute area via GeometryReader if needed
      if isCopy {
        item.copyToClipboard()
      } else {
        item.isSelected.toggle()
        appState.updateFooterItemVisibility()
      }
    }
    .onHover { hovering in
      if hovering { appState.selectWithoutScrolling(item.id) }
    }
  }
}
```

**Why**

- The universal view **intentionally** maps to your existing `ListItemView` row, preserving micro‑interactions and visuals.
    
- Zero duplication of row affordances.
    

**Impacts**

- None to clipboard path; this is used only by non‑clipboard tabs in Phase 1.
    

---

### 1.6 Dynamic tab system & wiring (ContentView)

**Modify** `nozzle/Views/ContentView.swift`  
**Where**: top state vars; tab row; main content switch; input binding.

**Changes**

- Inject `ContentManager` into environment.
    
- Replace hard‑coded tabs with dynamic tabs from `contentManager.getAllSources()`.
    
- Keep clipboard tab using existing `HistoryListView`; non‑clipboard tabs use `UniversalListView`.
    
- Input field binding:
    
    - If active tab == clipboard → bind to `appState.history.searchQuery` (current code).
        
    - Else → bind to `contentManager.sources[activeSourceId]?.searchQuery`.
        

**Example edits**

**1) Add environment**

```swift
@Environment(ContentManager.self) private var contentManager
```

**2) Replace static tabs** (inside the “Controls and tab buttons row”)

```swift
// Aggregated tab placeholder (“#”) stays for Phase 2; show it but keep inert for now.
TabButton(title: "#", isSelected: selectedTab == "aggregated") {
  selectedTab = "aggregated"
}

// Dynamic tabs
ForEach(contentManager.getAllSources(), id: \.id) { src in
  TabButton(title: src.name, isSelected: selectedTab == src.id) {
    selectedTab = src.id
    contentManager.activeSourceId = src.id
  }
}

// "+" to add a folder source
TabButton(title: "+", isSelected: false) { openFolderPickerAndRegister() }
```

**3) Input binding**  
At the `UnifiedInputFieldView` call site, change binding provider:

```swift
UnifiedInputFieldView(
  query: appState.isSearchMode
    ? Binding(
        get: {
          contentManager.activeSourceId == "clipboard"
            ? appState.history.searchQuery
            : (contentManager.sources[contentManager.activeSourceId]?.searchQuery ?? "")
        },
        set: { newValue in
          if contentManager.activeSourceId == "clipboard" {
            appState.history.searchQuery = newValue
          } else {
            contentManager.sources[contentManager.activeSourceId]?.searchQuery = newValue
          }
        }
      )
    : $appState.promptText,
  isSearchMode: appState.isSearchMode,
  isFocused: $inputFocused
)
```

**4) Main content switch** (inside the main HStack)

```swift
if contentManager.activeSourceId == "clipboard" {
  HistoryListView(
    searchQuery: $appState.history.searchQuery,
    searchFocused: $inputFocused
  )
} else {
  let items = contentManager.getItems(for: contentManager.activeSourceId)
    .map(UniversalItemDecorator.init)
  UniversalListView(items: items)
}
```

**5) Helper to add folder**

```swift
@MainActor
private func openFolderPickerAndRegister() {
  let panel = NSOpenPanel()
  panel.allowsMultipleSelection = false
  panel.canChooseDirectories = true
  panel.canChooseFiles = false
  if panel.runModal() == .OK, let url = panel.url {
    try? Bookmarks.store(url: url)
    let src = FileSystemSource(folderURL: url)
    contentManager.registerSource(src)
    Task { await src.refresh() }
    selectedTab = src.id
    contentManager.activeSourceId = src.id
  }
}
```

**Why**

- Dynamic tabs are the “aha” moment in the UI; this is the smallest, low‑risk change that showcases multi‑source without touching clipboard internals.
    
- Input binding logic keeps the single input field working across tabs.
    

**Impacts**

- `ContentView` now depends on `ContentManager`.
    
- Slight change to `TabButton` wiring; all else remains intact.
    

---

### 1.7 App shell & environment injection

**Modify** `nozzle/AppDelegate.swift`

- **Where**: `applicationDidFinishLaunching` and `panel = FloatingPanel(…) { ContentView() }` block.
    

**Changes**

1. **Register Clipboard source** after Clipboard starts:
    

```swift
let cm = ContentManager.shared
cm.registerSource(ClipboardSource())
```

2. **Restore folder sources** from bookmarks and register:
    

```swift
for url in Bookmarks.resolveAll() {
  let src = FileSystemSource(folderURL: url)
  cm.registerSource(src)
  Task { await src.refresh() }
}
```

3. **Inject environment**:
    

```swift
panel = FloatingPanel(
  contentRect: NSRect(origin: .zero, size: Defaults[.windowSize]),
  identifier: Bundle.main.bundleIdentifier ?? "org.conmeara.nozzle",
  statusBarButton: statusItem.button
) {
  ContentView()
    .environment(ContentManager.shared)
}
```

**Why**

- Sources must be available before `ContentView` loads for tabs to render.
    
- Injection keeps `ContentManager` a single shared observable (mirrors `AppState.shared` pattern).
    

**Impacts**

- None to clipboard timing or behavior.
    

---

### 1.8 Entitlements & configuration (Sandbox)

**Modify** `nozzle/nozzle.entitlements`  
**Add keys**

- `com.apple.security.files.user-selected.read-only` = **true**
    
- (Optional for Phase 2 write support) `com.apple.security.files.user-selected.read-write` = **false**
    
- Ensure App Sandbox is enabled.
    

**Why**

- Folder monitoring/scanning needs user‑selected read access.
    
- We’re persisting bookmarks; these entitlements are mandatory.
    

**Impacts**

- You will request folder permission on selection only.
    

---

### 1.9 Footer visibility logic aware of non‑clipboard selection

**Modify** `nozzle/Observables/AppState.swift` → `updateFooterItemVisibility()`  
**Where**: the method body that currently reads clipboard selection only.  
**Change**: also check `ContentManager` when non‑clipboard tab is active.

**New logic (conceptual)**

```swift
let isClipboard = ContentManager.shared.activeSourceId == "clipboard"
let hasSelected = isClipboard
  ? !history.selectedItems.isEmpty
  : !ContentManager.shared.nonClipboardSelection.isEmpty  // Phase 1

let hasContent = hasSelected || !promptText.isEmpty
pasteItem.isVisible = hasContent
```

**Why**

- The combined paste footer item should be visible for non‑clipboard selections as well.
    

**Impacts**

- None on clipboard behavior; adds parity for other tabs.
    

---

## PHASE 2 — Centralizing selection & cross‑source operations (opt‑in)

> You can ship Phase 1 first. Phase 2 aligns selections, aggregated tabs, and operations across sources—future‑proof but larger in scope.

### 2.1 Move selection into `ContentManager`

**Modify** `nozzle/Observables/ContentManager.swift`

- **Add**
    
    ```swift
    private(set) var selectedItemIds: Set<UUID> = []
    var selectedItems: [ContentItem] {
      get { allItems.filter { selectedItemIds.contains($0.id) } }
    }
    var allItems: [ContentItem] {
      orderedSourceIds.flatMap { sources[$0]?.items ?? [] }
    }
    func toggleSelection(_ id: UUID) { if !selectedItemIds.remove(id) { selectedItemIds.insert(id) } }
    ```
    
- **Clipboard bridge**: on selection changes, mirror state into `HistoryItemDecorator.isSelected` when `sourceType == .clipboard`.
    

**Why**

- A single selection set enables the **“# Aggregated”** tab and cross‑source paste/copy.
    

**Impacts**

- `HistoryItemView` selection toggles should call into `ContentManager.toggleSelection(_:)` **in addition to** setting `HistoryItemDecorator.isSelected` (temporary dual write until we fully switch).
    

### 2.2 Aggregated tab implementation

**Modify** `nozzle/Views/ContentView.swift`

- Make the “#” tab show `UniversalListView` fed by `contentManager.selectedItems.map(UniversalItemDecorator.init)`.
    

**Why**

- Show cross‑source selections in one place.
    

**Impacts**

- Footer “paste combined” becomes tab‑agnostic (next item).
    

### 2.3 Cross‑source combined paste

**Modify** `nozzle/Observables/AppState.swift`

- **Where**: `performCombinedPaste()` family.
    
- **Change**: instead of reading `history.selectedItems`, read `ContentManager.shared.selectedItems`.
    
- **Clipboard compatibility**: For History items, reuse existing formatting extraction; for file and text items from other sources, use the `ContentItem` payload in the new path.
    

**Example**

```swift
let selected = ContentManager.shared.selectedItems
let textItems   = selected.filter { $0.imageData == nil && $0.fileURL == nil }
let mediaItems  = selected.filter { $0.imageData != nil || $0.fileURL != nil }
```

**Why**

- Centralizes logic once selection is centralized.
    

**Impacts**

- Clipboard multi‑paste suppression (`Clipboard.setMultiPasteMode`) remains unchanged.
    

### 2.4 Replace clipboard row with unified wrapper (optional)

**Modify** `nozzle/Views/HistoryItemView.swift`

- Replace with (or wrap in) `UniversalItemView` to remove the last UI fork.
    
- **Side‑effect**: Ensure shortcuts and copy‑button affordances remain identical. You may temporarily keep History‑specific gestures in a thin adapter.
    

---

## Phase 1 & 2 — Interface and structure changes summary

### New files (Phase 1)

- `Protocols/ContentSource.swift` — **new**
    
- `Protocols/ContentItem.swift` — **new**
    
- `Protocols/ContentSourceType.swift` — **new**
    
- `Observables/ContentManager.swift` — **new**
    
- `Observables/UniversalItemDecorator.swift` — **new** (non‑clipboard Phase 1)
    
- `Sources/ClipboardSource.swift` — **new** (adapter)
    
- `Sources/FileSystemSource.swift` — **new** (initial scan + cache)
    
- `Utils/SecurityScopedBookmarks.swift` — **new**
    
- `Views/UniversalListView.swift` — **new**
    
- `Views/UniversalItemView.swift` — **new**
    

### Modified files (Phase 1)

- `Views/ContentView.swift`
    
    - **Tabs**: Replace static with dynamic tabs using `ContentManager`.
        
    - **Input binding**: Switch binding based on active tab (clipboard vs. other).
        
    - **Content switch**: Use `HistoryListView` for clipboard; `UniversalListView` for others.
        
    - **Add folder** handler: add NSOpenPanel flow.
        
- `AppDelegate.swift`
    
    - Register and inject `ContentManager.shared`.
        
    - Register `ClipboardSource` and folder sources from bookmarks; kick off `refresh()`.
        
- `nozzle.entitlements`
    
    - Add `com.apple.security.files.user-selected.read-only`.
        
- `Observables/AppState.swift`
    
    - Make `updateFooterItemVisibility()` aware of non‑clipboard selection sources (Phase 1).
        
    - (Phase 2) Migrate `performCombinedPaste()` to pull from `ContentManager.selectedItems`.
        

### Modified files (Phase 2)

- `Observables/ContentManager.swift`
    
    - Add `selectedItemIds` and unify selection.
        
- `Views/ContentView.swift`
    
    - Implement “#” aggregated tab bound to `contentManager.selectedItems`.
        
- `Views/HistoryItemView.swift`
    
    - Route selection toggles via `ContentManager.toggleSelection(_:)` in addition to current behavior; optional unification to `UniversalItemView`.
        
- `Observables/AppState.swift`
    
    - Use cross‑source selection in paste routines.
        

---

## Critical architectural decisions (call‑outs)

1. **Phased selection centralization**
    
    - **Decision**: Keep clipboard selection **unchanged** in Phase 1; add a separate selection set in `ContentManager` for non‑clipboard sources; centralize in Phase 2.
        
    - **Reasoning**: Preserves clipboard reliability; minimizes initial risk.
        
    - **Side‑effects**: Footer visibility logic needs to consider both worlds in Phase 1.
        
2. **Adapter for clipboard**
    
    - **Decision**: Introduce `ClipboardSource` that **reads** from `History` without mutating it.
        
    - **Reasoning**: No clipboard regressions; isolates the new architecture from legacy code paths.
        
3. **Unified row reuse vs. fork**
    
    - **Decision**: Create `UniversalItemView` that feeds `ListItemView` so visuals/behavior match clipboard rows.
        
    - **Reasoning**: Eliminates UI drift, reduces maintenance.
        
4. **Lazy file monitoring**
    
    - **Decision**: Phase 1 uses ad‑hoc `refresh()`; Phase 2 may enable FSEvents/Dispatch FSObject sources and thumbnails.
        
    - **Reasoning**: Keeps I/O off main without heavy infra; upgrade path exists.
        
5. **Security & bookmarks**
    
    - **Decision**: Persist folder permissions using security‑scoped bookmarks; minimal entitlement footprint.
        
    - **Reasoning**: Required by Sandbox; users explicitly grant access.
        

---

## API / signatures cheat‑sheet

- **ContentSource registration**
    
    ```swift
    ContentManager.shared.registerSource(ClipboardSource())
    ContentManager.shared.registerSource(FileSystemSource(folderURL: url))
    ```
    
- **Search**
    
    - Per‑source via `source.searchQuery` binding.
        
    - Global (Phase 2) via `ContentManager.searchAcrossAllSources(query:) -> [ContentItem]`.
        
- **Selection (Phase 2)**
    
    ```swift
    ContentManager.shared.toggleSelection(itemId)
    let selected = ContentManager.shared.selectedItems
    ```
    
- **Copy (universal)**
    
    ```swift
    UniversalItemDecorator.copyToClipboard()
    ```
    

---

## Data structure changes

- **New** `ContentItem` model to carry normalized item data across sources (keeps optional payloads to avoid forced conversions in Phase 1).
    
- **New** `ContentSourceType` enum to let UI and manager understand the source semantics.
    
- **No change** to `History`, `HistoryItemDecorator` in Phase 1; only read via adapter.
    

---

## Interface changes

- **ContentView**:
    
    - New dynamic tab bar built from `ContentManager.getAllSources()`.
        
    - Input field switches its binding target based on active tab (clipboard vs. per‑source).
        
    - “+” button opens folder picker and registers a new `FileSystemSource`.
        
    - (Phase 2) “#” aggregated tab shows selection across all sources.
        
- **Footer**:
    
    - “Paste combined” visibility conditions consider non‑clipboard selections in Phase 1; later use `ContentManager.selectedItems`.
        

---

## Configuration updates

- **Entitlements**:
    
    - `com.apple.security.files.user-selected.read-only = true`
        
    - Keep write disabled unless needed in future sources.
        
- **Info.plist**: no changes required for Phase 1 (status bar, LSUIElement already set).
    

---

## Potential side‑effects & mitigations

- **Two selection systems in Phase 1**
    
    - Clipboard selection remains in `HistoryItemDecorator`; non‑clipboard selection tracked in `ContentManager`.
        
    - _Mitigation_: Footer visibility reads both; internal paste routines remain clipboard‑centric until Phase 2.
        
- **Clipboard reorder after copy button**
    
    - Existing delayed reorder logic (in `History`) remains intact for clipboard; non‑clipboard sources do not reorder (they always reflect the file system order).
        
    - _Mitigation_: No action needed; behavior is consistent per source model.
        
- **Performance when scanning large folders**
    
    - `refresh()` runs off main; updates on MainActor; list sorted by timestamp.
        
    - _Mitigation_: Consider simple throttling in `ContentManager` if user adds very large directories.
        
- **Icon resolution/app images**
    
    - Universal rows don’t show app icons in Phase 1 (set `appIcon: nil`); can be added later by inferring UTType/application.
        
    - _Mitigation_: Keeps initial implementation minimal; add later if desired.
        

---

## Exact code touchpoints (by file)

- **`Views/ContentView.swift`**
    
    - **Add** `@Environment(ContentManager.self)` property.
        
    - **Replace** static tab HStack with `ForEach(contentManager.getAllSources())`.
        
    - **Add** `openFolderPickerAndRegister()` function beneath the `body` or as a private extension.
        
    - **Switch** main list body on `contentManager.activeSourceId` (`HistoryListView` vs `UniversalListView`).
        
    - **Modify** input binding inside `UnifiedInputFieldView` call.
        
- **`AppDelegate.swift`**
    
    - **After** `Clipboard.shared.start()` and preference wiring, **register** sources (clipboard + bookmarked folders).
        
    - **Change** FloatingPanel construction to inject `.environment(ContentManager.shared)`.
        
- **`Observables/AppState.swift`**
    
    - **Modify** `updateFooterItemVisibility()` to consult `ContentManager` (Phase 1).
        
    - **(Phase 2)** Edit `performCombinedPaste()` family to read from `ContentManager.selectedItems`.
        
- **`nozzle.entitlements`**
    
    - **Add** `com.apple.security.files.user-selected.read-only`.
        
- **New files** listed above (Protocols, Sources, Observables, Views, Utils).
    

---

## What _not_ to change in Phase 1

- **Selection** inside clipboard views (`HistoryListView`, `HistoryItemView`) — leave as is.
    
- **Clipboard polling & paste synthesis** — unchanged; wrapped by adapter only for UI and tab generation.
    
- **Search engine** for clipboard — continue using existing `Search` and `History.searchQuery`.
    

---

## Ready‑to‑build order of work

1. **Add protocols** (`ContentSourceType`, `ContentItem`, `ContentSource`).
    
2. **Add `ContentManager`** (register, lookup, active tab).
    
3. **Add `ClipboardSource`** adapter.
    
4. **Inject `ContentManager`** in `AppDelegate`; register clipboard source.
    
5. **Modify `ContentView`** tabs, input binding switch, and list switch.
    
6. **Add folder picker + bookmarks utility**; register `FileSystemSource`; call `refresh()`.
    
7. **Add universal decorator & views** (`UniversalItemDecorator`, `UniversalItemView`, `UniversalListView`).
    
8. **Footer visibility**: adjust `updateFooterItemVisibility()` to include non‑clipboard selection.
    
9. **(Optional now / later)** Add aggregated tab view stub (`#`) and wire selection centralization for Phase 2.
    
10. **Entitlements**: enable user‑selected read‑only.
    

---

This plan keeps Phase 1 **surgical and low‑risk**, adds real value (folder source + dynamic tabs), and leaves **clean seams**for Phase 2 (centralized selection, aggregated tab, FSEvents, thumbnails, more sources).