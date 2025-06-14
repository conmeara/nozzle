# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository (nozzle - enhanced fork of Maccy).

**Last Updated**: After implementing multi-select, prompt mode, and UI enhancements in the nozzle fork.

## Project Overview

nozzle is a macOS clipboard manager application built with Swift and SwiftUI. It runs as a menu bar app that monitors the clipboard and maintains a searchable history of copied items.

**nozzle is an enhanced fork of the original Maccy** that adds multi-select capabilities, prompt mode for combining items with instructions, and improved keyboard navigation.

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

### Core Components

1. **nozzleApp.swift**: Main SwiftUI app entry point with @main attribute
2. **AppDelegate.swift**: Handles app lifecycle, menu bar icon, global hotkeys, and clipboard monitoring
3. **Clipboard.swift**: Core clipboard monitoring and management logic
4. **History.swift**: Observable object managing clipboard history with Core Data backing
5. **AppState.swift**: Enhanced state management with multi-select and prompt mode support
6. **UnifiedInputFieldView.swift**: Adaptive input field that switches between search and prompt modes

### Data Flow

1. **Clipboard Monitoring**: AppDelegate starts clipboard monitoring on launch
2. **Storage**: Uses Core Data with two models:
   - History.xcdatamodeld: Legacy storage (being migrated from)
   - Storage.xcdatamodeld: Current storage model
3. **UI Updates**: Observable objects (AppState, History, Footer) drive SwiftUI views
4. **Global Hotkey**: Default Shift+Cmd+C opens the history popup

### Key Patterns

- **Observable Architecture**: Heavy use of @Published properties and ObservableObject
- **SwiftUI + AppKit**: SwiftUI for UI with AppKit for system integration (NSPasteboard, NSStatusItem)
- **Dependency Injection**: Settings and state passed through environment
- **Localization**: All user-facing strings use NSLocalizedString with 26+ language support
- **Multi-Select State**: Selection state tracked in History items with checkbox UI
- **Mode Switching**: AppState manages search vs prompt mode transitions

### Important Dependencies

- **Sparkle**: Auto-update framework
- **KeyboardShortcuts**: Global hotkey management
- **Settings**: Preferences window framework
- **Sauce**: Keyboard input handling
- **Defaults**: Type-safe UserDefaults wrapper

### Testing Approach

- Unit tests focus on models and business logic
- UI tests verify end-to-end functionality
- Test plan includes retry-on-failure for flaky tests
- Some Core Data migration tests are disabled in the test plan

## New Features Added in Fork

### Multi-Select System
- Each history item can be selected via checkbox
- Selection state tracked with `isChecked` property on items
- Visual feedback with blue background for selected items
- Keyboard shortcuts: Enter toggles selection, Cmd+N toggles nth item

### Prompt Mode
- Toggle between search and prompt mode with Cmd+F
- UnifiedInputFieldView adapts UI based on mode
- Multi-line input support (up to 4 lines) in prompt mode
- Prompt text combined with selected items using template

### Combined Operations
- Cmd+V: Paste combined content (prompt + selected items)
- Cmd+Enter: Copy combined content to clipboard
- Template system with {prompt} and {items} placeholders
- Default template: "{prompt}\nContext:\n{items}"

### Enhanced Keyboard Navigation
- Plain Enter: Toggle selection (changed from copy)
- Cmd+Shift+Enter: Paste single item (bypass multi-select)
- Option+Space: Toggle preview
- Cmd+Delete: Clear all selections and prompt

### UI Improvements
- Cleaner visual design with refined spacing
- Better focus indicators
- Contextual footer items (only show when relevant)
- Smooth animations (0.15s transitions)

## Key Implementation Details

### AppState Enhancements
```swift
// New properties
@Published var isPromptMode: Bool
@Published var promptText: String
var selectedItems: [HistoryItem] // computed from history

// New methods
func performCombinedPaste()
func performCombinedCopy()
func formatCombinedContent() -> String
func clearSelectionAndPrompt()
```

### User Defaults
- `pasteTemplate`: Configurable template for combined operations

### Testing Considerations
- Test multi-select state management
- Test mode switching behavior
- Test combined operation formatting
- Test keyboard shortcut conflicts