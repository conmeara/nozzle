# nozzle v3 Architecture Guide

## Overview

This document provides a comprehensive guide to the nozzle v3 architecture transformation from clipboard manager to universal content aggregation platform.

## Architecture Transformation

### Before v3: Clipboard-Only Architecture
```
┌─────────────────────────────────────┐
│             UI Layer                │
│    ContentView → HistoryListView    │
└─────────────────┬───────────────────┘
                  │
┌─────────────────▼───────────────────┐
│           State Layer               │
│      AppState + History             │
└─────────────────┬───────────────────┘
                  │
┌─────────────────▼───────────────────┐
│          Data Layer                 │
│      Clipboard → Core Data          │
└─────────────────────────────────────┘
```

### After v3: Multi-Source Architecture
```
┌─────────────────────────────────────────────────────────┐
│                    UI Layer                             │
│  ContentView → Dynamic Tabs → Universal/History Views  │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│                Coordination Layer                       │
│           ContentManager (Central Hub)                 │
│     • Source Registration & Management                 │
│     • Cross-Source Selection System                    │
│     • Active Source & Tab State                        │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│                 Protocol Layer                          │
│      ContentSource Protocol + ContentItem              │
│            (Unified Interface)                          │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│               Implementation Layer                      │
│ ClipboardSource │ FileSystemSource │ Future Sources    │
│   (Adapter)     │  (File Monitor)  │  (Extensible)     │
└─────────────────────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│                  Data Layer                             │
│  Core Data (Clipboard) │ FileSystem │ Future Storage   │
└─────────────────────────────────────────────────────────┘
```

## Core Components Deep Dive

### 1. ContentManager - Central Coordinator

**Purpose**: Single point of coordination for all content sources and cross-source operations.

**Key Responsibilities**:
- Source registration and lifecycle management
- Centralized selection state across all sources
- Active source tracking for UI state
- Aggregated view data provision

**Implementation Pattern**: Observable Singleton
```swift
@Observable @MainActor
final class ContentManager {
    static let shared = ContentManager()
    
    // Source management
    private(set) var sources: [String: any ContentSource] = [:]
    private(set) var orderedSourceIds: [String] = []
    var activeSourceId: String = "clipboard"
    
    // Cross-source selection
    private(set) var selectedItemIds: Set<UUID> = []
}
```

### 2. ContentSource Protocol - Universal Interface

**Purpose**: Unified interface enabling unlimited content source types.

**Design Pattern**: Protocol-Oriented Programming
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

**Benefits**:
- Zero coupling between UI and specific source implementations
- Infinite extensibility for new content types
- Consistent interface regardless of underlying technology
- Easy testing via protocol mocking

### 3. ContentItem - Unified Data Model

**Purpose**: Single data structure representing content from any source.

**Design Pattern**: Value Type with Optional Payloads
```swift
public struct ContentItem: Identifiable, Hashable, Sendable {
    // Core identification
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

**Benefits**:
- Uniform representation across all content types
- Future-safe with optional payload fields
- SwiftUI-friendly with Identifiable conformance
- Thread-safe with Sendable conformance

## Source Implementations

### ClipboardSource - Backward Compatibility Adapter

**Purpose**: Wraps existing clipboard functionality without modification.

**Pattern**: Adapter Pattern
- **Zero Risk**: No changes to existing clipboard code paths
- **Read-Only Adaptation**: Maps HistoryItemDecorator → ContentItem
- **Selection Bridging**: Maintains two-way sync with History selection

**Implementation Strategy**:
```swift
var items: [ContentItem] {
    history.items.map { decorator in
        ContentItem(
            id: decorator.id,
            title: decorator.title,
            // ... map all properties
            isSelected: decorator.isSelected
        )
    }
}
```

### FileSystemSource - Folder Monitoring

**Purpose**: Monitors file system directories as content sources.

**Key Features**:
- **Security-Scoped Bookmarks**: Persistent folder access across app restarts
- **Stable UUIDs**: SHA256-based deterministic identification
- **Async Scanning**: Off-main-thread directory scanning
- **Search Integration**: File name and path content filtering

**Security Implementation**:
```swift
// Store bookmark
let bookmarkData = try url.bookmarkData(
    options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
    includingResourceValuesForKeys: nil,
    relativeTo: nil
)

// Resolve bookmark
let url = try URL(
    resolvingBookmarkData: data,
    options: [.withSecurityScope],
    relativeTo: nil,
    bookmarkDataIsStale: &isStale
)
```

## UI Architecture

### Dynamic Tab System

**Purpose**: Automatically generate tabs based on registered content sources.

**Implementation**:
```swift
// Dynamic tabs generation
ForEach(contentManager.getAllSources(), id: \.id) { src in
    TabButton(title: src.name, isSelected: selectedTab == src.id) {
        selectedTab = src.id
        contentManager.activeSourceId = src.id
    }
}
```

**Special Tabs**:
- **"#" Aggregated Tab**: Shows selected items from all sources
- **"+" Add Tab**: Opens folder picker for new FileSystemSource

### Universal View System

**Purpose**: Consistent UI across all content source types.

**Architecture**:
```
UniversalListView
    ├── UniversalItemView (per item)
    │   └── ListItemView (shared component)
    └── UniversalItemDecorator (data adapter)
```

**Benefits**:
- **UI Consistency**: Same visual appearance across all sources
- **Code Reuse**: Leverages existing ListItemView component
- **Interaction Parity**: Identical gestures and behaviors

### Input Field Adaptation

**Purpose**: Single input field adapts behavior based on active source.

**Dynamic Binding**:
```swift
UnifiedInputFieldView(
    query: Binding(
        get: {
            contentManager.activeSourceId == "clipboard"
                ? appState.history.searchQuery
                : contentManager.sources[activeSourceId]?.searchQuery ?? ""
        },
        set: { newValue in
            if contentManager.activeSourceId == "clipboard" {
                appState.history.searchQuery = newValue
            } else {
                contentManager.sources[activeSourceId]?.searchQuery = newValue
            }
        }
    )
)
```

## Cross-Source Selection System

### Centralized Selection Management

**Challenge**: Multiple sources with different selection paradigms
**Solution**: Single source of truth in ContentManager

```swift
// Central selection state
private(set) var selectedItemIds: Set<UUID> = []

// Computed cross-source selections
var selectedItems: [ContentItem] {
    allItems.filter { selectedItemIds.contains($0.id) }
}

// Universal selection toggle
func toggleSelection(_ id: UUID) {
    if selectedItemIds.remove(id) == nil {
        selectedItemIds.insert(id)
    }
    syncClipboardSelection(id) // Bridge to History
}
```

### Selection Bridging

**Purpose**: Maintain compatibility with existing clipboard selection UI.

**Two-Way Sync**:
- ContentManager selection changes → History.isSelected updates
- History selection changes → ContentManager updates (for clipboard items)

### Aggregated Operations

**Combined Paste/Copy**: Works with heterogeneous content from multiple sources
```swift
func performCombinedPaste() {
    let selectedItems = ContentManager.shared.selectedItems
    let textItems = selectedItems.filter { $0.plainText != nil }
    let fileItems = selectedItems.filter { $0.fileURL != nil }
    // Process mixed content types
}
```

## Security Architecture

### Security-Scoped Bookmarks

**Purpose**: Maintain persistent folder access in App Sandbox environment.

**Lifecycle**:
1. **User Selection**: NSOpenPanel for folder selection
2. **Bookmark Creation**: Security-scoped bookmark data generation
3. **Persistent Storage**: UserDefaults storage with path-based keys
4. **App Restart**: Bookmark resolution and access restoration
5. **Stale Cleanup**: Automatic removal of invalid bookmarks

**Implementation**:
```swift
enum Bookmarks {
    static func store(url: URL) throws
    static func resolveAll() -> [URL]
    static func remove(url: URL)
}
```

### Entitlements

**Required Entitlements**:
```xml
<key>com.apple.security.files.user-selected.read-only</key>
<true/>
<key>com.apple.security.app-sandbox</key>
<true/>
```

## Extension Points

### Adding New Content Sources

**Step 1**: Implement ContentSource Protocol
```swift
class NotesSource: ContentSource {
    let id = "notes"
    let name = "Notes"
    let icon = NSImage(systemSymbolName: "note.text")!
    let type: ContentSourceType = .notes // Add to enum
    
    // Implement required methods...
}
```

**Step 2**: Register with ContentManager
```swift
ContentManager.shared.registerSource(NotesSource())
```

**Step 3**: UI automatically adapts
- New tab appears
- Universal views handle rendering
- Selection system includes new content
- Search works across all sources

### Future Source Examples

**Potential Sources**:
- **Screenshot Source**: Monitor Screenshots folder
- **Notes Source**: Integrate with Notes.app database
- **Cloud Source**: Dropbox/Google Drive integration
- **Web Source**: Bookmark and web page monitoring
- **Code Source**: Git repository monitoring
- **Document Source**: Recent documents tracking

## Performance Considerations

### Async Operations

**File Scanning**: Off-main-thread directory scanning
```swift
func refresh() async {
    let task = Task.detached { [folderURL] () -> [ContentItem] in
        // Heavy file system operations here
    }
    let items = await task.value
    await MainActor.run { self.cachedItems = items }
}
```

### Memory Management

**Lazy Loading**: Sources load content on-demand
**Caching Strategy**: Each source manages its own cache
**Selection Efficiency**: Set-based selection for O(1) lookup

### UI Optimization

**Observable Architecture**: Minimal UI updates via @Observable
**View Recycling**: Reuse existing ListItemView for all sources
**Dynamic Rendering**: Only active source content rendered

## Migration Strategy

### Phase 1: Foundation (✅ Completed)
- Protocol layer implementation
- ContentManager coordinator
- ClipboardSource adapter
- FileSystemSource basic implementation
- Dynamic UI with backward compatibility

### Phase 2: Enhancement (✅ Completed)  
- Centralized selection system
- Cross-source operations
- Aggregated view
- Security-scoped bookmarks

### Future Phases
- FSEvents real-time monitoring
- Additional source types
- Advanced search across sources
- Source-specific preferences

## Testing Strategy

### Unit Testing
- ContentManager source registration/lifecycle
- Security-scoped bookmark persistence
- Cross-source selection management
- ContentItem UUID stability

### Integration Testing
- Dynamic tab generation
- Universal view rendering
- Source switching behavior
- Backward compatibility verification

### UI Testing
- Folder picker integration
- Cross-source selection workflows
- Aggregated view functionality
- Keyboard navigation across sources

## Conclusion

The nozzle v3 architecture represents a fundamental evolution from clipboard manager to universal content aggregation platform. The protocol-oriented design enables infinite extensibility while maintaining complete backward compatibility. The centralized coordination through ContentManager provides a clean separation of concerns, and the universal UI system ensures consistent user experience across all content types.

This architecture positions nozzle as a foundation for future content management innovation while preserving the simplicity and reliability that made it successful as a clipboard manager.