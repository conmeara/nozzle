# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Maccy is a macOS clipboard manager application built with Swift and SwiftUI. It runs as a menu bar app that monitors the clipboard and maintains a searchable history of copied items.

## Commands

### Building
```bash
# Build the app
xcodebuild -project Maccy.xcodeproj -scheme Maccy build

# Build for release
xcodebuild -project Maccy.xcodeproj -scheme Maccy -configuration Release build
```

### Testing
```bash
# Run all tests
xcodebuild -project Maccy.xcodeproj -scheme Maccy test

# Run specific test class
xcodebuild -project Maccy.xcodeproj -scheme Maccy test -only-testing:MaccyTests/ClipboardTests

# Run UI tests
xcodebuild -project Maccy.xcodeproj -scheme Maccy test -only-testing:MaccyUITests
```

### Archiving for Release
```bash
xcodebuild -project Maccy.xcodeproj -scheme Maccy archive -archivePath ./build/Maccy.xcarchive
```

## Architecture

### Core Components

1. **MaccyApp.swift**: Main SwiftUI app entry point with @main attribute
2. **AppDelegate.swift**: Handles app lifecycle, menu bar icon, global hotkeys, and clipboard monitoring
3. **Clipboard.swift**: Core clipboard monitoring and management logic
4. **History.swift**: Observable object managing clipboard history with Core Data backing

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

