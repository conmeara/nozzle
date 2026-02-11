# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Last Updated**: After implementing nozzle v3 multi-source architecture transformation.

## Project Overview

nozzle v3 is a revolutionary macOS content aggregation platform built with Swift and SwiftUI. What began as a clipboard manager has evolved into a universal multi-source content management system that unifies clipboard history, file system monitoring, and extensible content sources into a single, powerful interface.

**Key Architecture Transformation**: nozzle v3 implements a protocol-oriented, multi-source architecture that treats all content sources (clipboard, folders, future extensions) through a unified interface while maintaining complete backward compatibility with existing clipboard functionality.

### Core Design Principles

1. **Protocol-Oriented Architecture**: All content sources implement the `ContentSource` protocol
2. **Unified Interface**: Consistent UI and operations across all source types  
3. **Backward Compatibility**: Existing clipboard functionality unchanged
4. **Scalable Design**: Easy addition of new content source types
5. **Security-First**: Security-scoped bookmarks for persistent folder access
6. **Cross-Source Operations**: Selection and operations work across different source types

## Commands

### Building
```bash
# Build the app
xcodebuild -project nozzle.xcodeproj -scheme nozzle build

# Build for release
xcodebuild -project nozzle.xcodeproj -scheme nozzle -configuration Release build
```

### Testing
```bash
# Run all tests
xcodebuild -project nozzle.xcodeproj -scheme nozzle test

# Run specific test class
xcodebuild -project nozzle.xcodeproj -scheme nozzle test -only-testing:nozzleTests/ClipboardTests

# Run UI tests
xcodebuild -project nozzle.xcodeproj -scheme nozzle test -only-testing:nozzleUITests
```

### Archiving for Release
```bash
xcodebuild -project nozzle.xcodeproj -scheme nozzle archive -archivePath ./build/nozzle.xcarchive
```

## Architecture

### v3 Multi-Source Architecture Overview

nozzle v3 implements a layered, protocol-oriented architecture that enables unlimited content source types while preserving existing clipboard functionality.

```
┌─────────────────────────────────────────────────┐
│                  UI Layer                       │
│  ContentView → Dynamic Tabs → Universal Views  │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│              Coordination Layer                 │
│         ContentManager (Centralized)           │
│    • Source Registration & Management          │
│    • Cross-Source Selection System             │
│    • Active Source & Tab State                 │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│               Protocol Layer                    │
│    ContentSource Protocol + ContentItem        │
│         (Unified Interface)                     │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│             Implementation Layer               │
│  ClipboardSource │ FileSystemSource │ Future   │
│   (Adapter)      │  (File Monitor)  │ Sources  │
└─────────────────────────────────────────────────┘
```

### Core Components (v3)

#### Central Coordination
1. **ContentManager.swift**: 🆕 Central coordinator managing all content sources
   - Source registration and lifecycle
   - Cross-source selection management  
   - Active source state and tab coordination
   - Aggregated view logic

#### Protocol Layer (New in v3)
2. **ContentSource protocol**: 🆕 Universal interface for all content types
3. **ContentItem struct**: 🆕 Unified data model across sources
4. **ContentSourceType enum**: 🆕 Source type identification

#### Source Implementations
5. **ClipboardSource.swift**: 🆕 Adapter wrapping existing clipboard functionality
6. **FileSystemSource.swift**: 🆕 File/folder monitoring with security-scoped bookmarks
7. **SecurityScopedBookmarks.swift**: 🆕 Persistent folder access management

#### Universal UI Layer
8. **UniversalItemDecorator.swift**: 🆕 Adapter for non-clipboard items
9. **UniversalListView.swift**: 🆕 List view for non-clipboard sources
10. **UniversalItemView.swift**: 🆕 Item view using existing ListItemView

#### Existing Components (Enhanced)
11. **ContentView.swift**: ⚡ Enhanced with dynamic tabs and source switching
12. **AppState.swift**: ⚡ Enhanced with cross-source selection support
13. **AppDelegate.swift**: ⚡ Enhanced with source registration and environment injection

#### Unchanged Core (Backward Compatibility)
14. **nozzleApp.swift**: Main SwiftUI app entry point
15. **Clipboard.swift**: Core clipboard monitoring (unchanged)
16. **History.swift**: Clipboard history management (unchanged)
17. **HistoryListView.swift**: Clipboard-specific UI (unchanged)
18. **HistoryItemView.swift**: Clipboard item UI (unchanged)

### Data Flow (v3)

#### Source Registration & Initialization
1. **App Launch**: AppDelegate initializes ContentManager
2. **Source Registration**: 
   - ClipboardSource wraps existing History
   - FileSystemSources restored from security-scoped bookmarks
3. **Environment Injection**: ContentManager injected into UI environment

#### Content Aggregation
1. **Source Monitoring**: Each source monitors its content independently
2. **Unified Interface**: ContentManager provides unified access via ContentSource protocol
3. **Dynamic Tabs**: UI reflects registered sources automatically
4. **Real-time Updates**: Sources update independently, UI reacts via @Observable

#### Cross-Source Selection
1. **Centralized Selection**: ContentManager maintains selectedItemIds Set<UUID>
2. **Source Bridging**: Clipboard selections sync with History for compatibility
3. **Aggregated View**: "#" tab shows selections from all sources
4. **Combined Operations**: Operations work on heterogeneous content

### Key Patterns (v3)

#### Protocol-Oriented Design
- **ContentSource Protocol**: Uniform interface for all content types
- **Adapter Pattern**: ClipboardSource adapts existing History without changes
- **Strategy Pattern**: Different sources implement monitoring differently

#### Observable Architecture (Swift 6)
- **@Observable**: ContentManager, all sources, and decorators use new observation
- **MainActor Isolation**: All UI-touching code properly isolated
- **Reactive Updates**: Changes automatically propagate through observation

#### Security & Persistence
- **Security-Scoped Bookmarks**: Persistent folder access across app restarts
- **Sandboxed Access**: Proper entitlements for user-selected folders
- **Bookmark Lifecycle**: Automatic cleanup of stale bookmarks

#### Unified UI Patterns
- **Dynamic Tabs**: Tabs generated from registered sources
- **Universal Views**: Consistent UI across source types via shared ListItemView
- **Mode Switching**: Search/prompt modes work across all sources

#### Backward Compatibility
- **Zero Impact**: Existing clipboard code paths unchanged
- **Adapter Isolation**: ClipboardSource reads but doesn't modify History
- **Progressive Enhancement**: v3 features layer on top of existing functionality

### Important Dependencies

- **Defaults**: Type-safe UserDefaults wrapper (sindresorhus/Defaults 8.2.0)
- **KeyboardShortcuts**: Global hotkey management (sindresorhus/KeyboardShortcuts 2.0.2)
- **Settings**: Preferences window framework (sindresorhus/Settings 3.1.1)
- **Sauce**: Keyboard input handling (Clipy/Sauce 2.4.1)
- **LaunchAtLogin-Modern**: Launch at login functionality (sindresorhus/LaunchAtLogin-Modern 1.1.0)
- **Fuse**: Fuzzy search library (krisk/fuse-swift 1.4.0)
- **SwiftHEXColors**: Hex color utilities (thii/SwiftHEXColors 1.4.1)

### Testing Approach

- Unit tests focus on models and business logic (nozzleTests target)
- UI tests verify end-to-end functionality (nozzleUITests target)
- Test plan includes retry-on-failure for flaky tests
- Some Core Data migration tests (HistoryTests) are disabled in nozzle.xctestplan
- Tests run with `enable-testing` command line argument

## v3 Architecture Implementation

### Multi-Source Protocol System

#### ContentSource Protocol
```swift
@MainActor
public protocol ContentSource: AnyObject {
    var id: String { get }
    var name: String { get }
    var icon: NSImage { get }
    var type: ContentSourceType { get }
    var isMonitoring: Bool { get }
    var items: [ContentItem] { get }
    var searchQuery: String { get set }
    
    func startMonitoring()
    func stopMonitoring()
    func refresh() async
    func search(query: String) -> [ContentItem]
}
```

#### ContentItem Unified Model
```swift
public struct ContentItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let title: String
    public let timestamp: Date
    public let sourceType: ContentSourceType
    public let sourceId: String
    
    // Optional format-specific data
    public let fileURL: URL?
    public let imageData: Data?
    public let rtfData: Data?
    public let htmlData: Data?
    public let plainText: String?
    
    // UI state
    public var isSelected: Bool
    public var isVisible: Bool
}
```

### Source Implementations

#### ClipboardSource (Adapter)
- **Pattern**: Adapter wrapping existing History without modification
- **Backward Compatibility**: Zero impact on existing clipboard functionality
- **Integration**: Maps HistoryItemDecorator → ContentItem seamlessly
- **Selection Sync**: Maintains two-way sync with History selection state

#### FileSystemSource
- **Security**: Uses security-scoped bookmarks for persistent folder access
- **Stability**: SHA256-based UUID generation for consistent file identification
- **Performance**: Async scanning with MainActor updates
- **Search**: File name and path content filtering

#### ContentManager (Coordinator)
```swift
@Observable @MainActor
final class ContentManager {
    static let shared = ContentManager()
    
    private(set) var sources: [String: any ContentSource] = [:]
    private(set) var orderedSourceIds: [String] = []
    var activeSourceId: String = "clipboard"
    
    // Phase 2: Centralized selection
    private(set) var selectedItemIds: Set<UUID> = []
    
    var selectedItems: [ContentItem] { /* computed */ }
    var allItems: [ContentItem] { /* computed */ }
}
```

### Universal UI System

#### Dynamic Tab Generation
- Tabs automatically reflect registered sources
- "+" tab for adding new folder sources via NSOpenPanel  
- "#" aggregated tab for cross-source selections
- Seamless tab switching with source activation

#### Universal Views
- **UniversalListView**: Reusable list container for non-clipboard sources
- **UniversalItemView**: Adapts ContentItem to existing ListItemView
- **UniversalItemDecorator**: Observable wrapper for ContentItem with UI state

#### Cross-Source Selection
- **Centralized Management**: Single selectedItemIds Set in ContentManager
- **Source Bridging**: Clipboard selections sync with History for compatibility
- **Aggregated Operations**: Combined paste/copy works across source types
- **Visual Consistency**: Same selection UI across all sources

### Enhanced Features (Preserved from v2)

#### Multi-Select System (Enhanced)
- Selection now works across ALL content sources
- Centralized selection state in ContentManager
- Cross-source selection mixing clipboard + files
- Visual feedback consistent across source types

#### Prompt Mode (Enhanced) 
- Toggle between search and prompt mode with Cmd+F
- Works with content from any source type
- Multi-line input support (up to 4 lines)
- Template system supports heterogeneous content

#### Combined Operations (Enhanced)
- Cmd+V: Paste combined content from any sources
- Cmd+Enter: Copy combined content to clipboard  
- Template system with {prompt} and {items} placeholders
- Works with mixed content types (clipboard + files)

#### Advanced Keyboard Navigation
- Tab switching between content sources
- Universal selection shortcuts across source types
- Source-aware search and filtering
- Consistent keyboard behavior regardless of active source

## Key Implementation Details

### ContentManager Architecture
```swift
@Observable @MainActor
final class ContentManager {
    static let shared = ContentManager()
    
    // Source management
    private(set) var sources: [String: any ContentSource] = [:]
    private(set) var orderedSourceIds: [String] = []
    var activeSourceId: String = "clipboard"
    
    // Centralized selection (Phase 2)
    private(set) var selectedItemIds: Set<UUID> = []
    
    // Computed properties
    var selectedItems: [ContentItem] {
        allItems.filter { selectedItemIds.contains($0.id) }
    }
    
    var allItems: [ContentItem] {
        orderedSourceIds.flatMap { sources[$0]?.items ?? [] }
    }
    
    // Core methods
    func registerSource<T: ContentSource>(_ source: T)
    func toggleSelection(_ id: UUID)
    func clearSelection()
    func getAllSources() -> [any ContentSource]
}
```

### Security-Scoped Bookmarks Implementation
```swift
enum Bookmarks {
    static func store(url: URL) throws {
        let bookmarkData = try url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        // Store in UserDefaults with path key
    }
    
    static func resolveAll() -> [URL] {
        // Resolve all bookmarks, handle stale ones
        // Start accessing security-scoped resources
    }
}
```

### AppState Cross-Source Integration
```swift
// Enhanced methods for v3
func performCombinedPaste() {
    // Now works with ContentManager.shared.selectedItems
    // Supports mixed content types (clipboard + files)
}

func updateFooterItemVisibility() {
    // Considers selections from all sources
    let hasSelected = !ContentManager.shared.selectedItems.isEmpty
    let hasContent = hasSelected || !promptText.isEmpty
}
```

### Stable UUID Generation
```swift
// FileSystemSource uses deterministic UUIDs
let stableIdString = "\(url.absoluteString):\(modDate.timeIntervalSince1970)"
let hash = SHA256.hash(data: Data(stableIdString.utf8))
let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
let uuid = UUID(uuidString: formattedHash) ?? UUID()
```

### Dynamic UI Binding
```swift
// ContentView adapts input binding based on active source
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
        : $appState.promptText
)
```

### User Defaults (v3)
- `pasteTemplate`: Configurable template for combined operations (preserved)
- `nozzle.folder.bookmarks`: Security-scoped bookmark storage

### Entitlements Required
```xml
<key>com.apple.security.files.user-selected.read-only</key>
<true/>
<key>com.apple.security.app-sandbox</key>
<true/>
```

### Testing Considerations (v3)
- Test ContentManager source registration and lifecycle
- Test cross-source selection management
- Test security-scoped bookmark persistence
- Test dynamic tab generation and switching
- Test universal view rendering for different content types
- Test aggregated view with mixed selections
- Test backward compatibility with existing clipboard functionality
- Test folder picker integration and bookmark creation

## Project Structure

### Core Directories (v3)
- **nozzle/**: Main application source code
  - **Models/**: 🆕 Protocol definitions and unified data models
    - `ContentSource.swift`: Universal source interface
    - `ContentItem.swift`: Unified item model
    - `ContentSourceType.swift`: Source type enum
    - `HistoryItem.swift`: Existing clipboard data model
    - `HistoryItemContent.swift`: Existing clipboard content model
  - **Observables/**: State management (@Observable classes)
    - `ContentManager.swift`: 🆕 Central source coordinator
    - `ClipboardSource.swift`: 🆕 Clipboard adapter
    - `FileSystemSource.swift`: 🆕 Folder monitoring source
    - `UniversalItemDecorator.swift`: 🆕 Universal item wrapper
    - `AppState.swift`: ⚡ Enhanced with cross-source support
    - `History.swift`: Existing clipboard history
    - `HistoryItemDecorator.swift`: Existing clipboard item wrapper
    - `Popup.swift`, `Footer.swift`, `FooterItem.swift`, `ModifierFlags.swift`
  - **Views/**: SwiftUI views and UI components
    - `ContentView.swift`: ⚡ Enhanced with dynamic tabs
    - `UniversalListView.swift`: 🆕 Universal list container
    - `UniversalItemView.swift`: 🆕 Universal item view
    - `HistoryListView.swift`: Existing clipboard list
    - `HistoryItemView.swift`: Existing clipboard item
    - `UnifiedInputFieldView.swift`: Enhanced search/prompt input
    - Other UI components (FooterView, ListItemView, etc.)
  - **Extensions/**: Swift extensions for various types
    - `SecurityScopedBookmarks.swift`: 🆕 Bookmark management
    - Existing extensions for NSImage, String, Color, etc.
  - **Settings/**: Preferences panes with localization support
  - **Intents/**: App Intents for Shortcuts integration  
  - **Sounds/**: Audio assets (Knock.caf, Write.caf)
- **nozzleTests/**: Unit tests with test fixtures
- **nozzleUITests/**: UI automation tests
- **docs/**: Development documentation and design notes
  - `Nozzle v3 plan.md`: 🆕 Complete v3 architecture specification

### v3 File Organization

#### New Protocol Layer
```
Models/
├── ContentSource.swift      # Universal source interface
├── ContentItem.swift        # Unified data model
└── ContentSourceType.swift  # Source type enumeration
```

#### New Source Implementations  
```
Observables/
├── ContentManager.swift        # Central coordinator
├── ClipboardSource.swift      # Clipboard adapter
├── FileSystemSource.swift     # File/folder source
└── UniversalItemDecorator.swift # Universal item wrapper
```

#### New Universal UI Layer
```
Views/
├── UniversalListView.swift  # Universal list container
└── UniversalItemView.swift  # Universal item view
```

#### New Utilities
```
Extensions/
└── SecurityScopedBookmarks.swift # Persistent folder access
```

#### Enhanced Existing Files
```
Views/ContentView.swift      # Dynamic tabs + source switching
Observables/AppState.swift   # Cross-source selection support  
AppDelegate.swift           # Source registration + injection
```

### Localization
- Supports 26+ languages with .lproj directories
- Localized strings files for all UI components
- Main localizable files: Localizable.strings, *Settings.strings, PreviewItemView.strings
- v3 features use existing localization infrastructure

### Build Assets
- **Assets.xcassets/**: App icons, menu bar icons, and system images
- **nozzle.entitlements**: ⚡ Enhanced with user-selected file access
- **Info.plist**: App metadata and configuration

### Entitlements (v3)
```xml
<!-- Required for folder monitoring -->
<key>com.apple.security.files.user-selected.read-only</key>
<true/>

<!-- Existing entitlements preserved -->
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.automation.apple-events</key>
<true/>
```

## Permissions Troubleshooting Memory

If permissions loop or appear enabled but Nozzle still fails, it is usually a stale TCC identity (DMG/old build).

Use only `/Applications/nozzle.app` (`com.conmeara.nozzleai`, team `6TNDG45H72`), then run:

```bash
hdiutil detach "/Volumes/nozzle 3" 2>/dev/null || true
tccutil reset All com.conmeara.nozzleai
killall tccd || true
```

Re-launch Nozzle and re-enable:
- Accessibility
- Screen & System Audio Recording
- Microphone
- Speech Recognition

Then open Screenshot tab and press `Refresh`.

## Selected Items Caching

We optimized `ContentManager.selectedItems` to avoid repeated full scans/sorts and to keep the UI order stable.

Summary

- Complexity: O(#selected) with a cached array and dirty flag.
- Order: Preserve appearance order from the visible list; parents before children; no timestamp sort.
- Stability: Prevents reordering jitter in the Aggregated (“#”) tab and elsewhere.

Implementation Sketch

```swift
@ObservationIgnored private var _selectedCache: [ContentItem] = []
@ObservationIgnored private var _selectedCacheDirty = true

var selectedItems: [ContentItem] {
    if _selectedCacheDirty { _selectedCache = makeSelectedItems(); _selectedCacheDirty = false }
    return _selectedCache
}

func markSelectedDirty() { _selectedCacheDirty = true }

private func makeSelectedItems() -> [ContentItem] {
    // Traverse allItems in appearance order.
    // Include selected parents and parents of selected children, then selected children.
}
```

Dirty Invalidation Triggers

- Selection changes: `toggleSelection`, folder select/deselect helpers, `clearSelection`.
- Example state changes: `toggleExample` (may alter selection set).
- Source updates: `FileSystemSource.refresh()` and `refreshFolderSlice(at:)`.
- Clipboard updates: `History.items` `didSet`.
- Source removal and expansion events: `removeSource(_:)`, `handleFolderExpansion(_:)`.

Maintainer Guidance

- When a source changes its visible item order or filtering, call `ContentManager.shared.markSelectedDirty()` after updating to keep the aggregated selection view consistent.
