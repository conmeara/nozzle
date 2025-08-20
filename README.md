
<img width="128px" src="https://nozzle.app/img/nozzle/Logo.png" alt="Logo" align="left" />

# nozzle v3 - Universal Content Aggregation Platform

[![Downloads](https://img.shields.io/github/downloads/conmeara/nozzle/total.svg)](https://github.com/conmeara/nozzle/releases/latest)
[![Build Status](https://img.shields.io/bitrise/716921b669780314/master?token=3pMiCb5dpFzlO-7jTYtO3Q)](https://app.bitrise.io/app/716921b669780314)

**nozzle has evolved from a clipboard manager into a universal multi-source content aggregation platform.**

nozzle v3 is a revolutionary content management tool for macOS that unifies clipboard history, 
file system monitoring, and future content sources into a single, powerful interface. It maintains 
all the beloved clipboard management features while introducing a scalable architecture for 
unlimited content types.

nozzle works on macOS Sonoma 14 or higher.

<!-- vim-markdown-toc GFM -->

* [Features](#features)
* [Install](#install)
* [Usage](#usage)
* [Advanced](#advanced)
  * [Ignore Copied Items](#ignore-copied-items)
  * [Ignore Custom Copy Types](#ignore-custom-copy-types)
  * [Speed up Clipboard Check Interval](#speed-up-clipboard-check-interval)
* [FAQ](#faq)
  * [Why doesn't it paste when I select an item in history?](#why-doesnt-it-paste-when-i-select-an-item-in-history)
  * [When assigning a hotkey to open nozzle, it says that this hotkey is already used in some system setting.](#when-assigning-a-hotkey-to-open-maccy-it-says-that-this-hotkey-is-already-used-in-some-system-setting)
  * [How to restore hidden footer?](#how-to-restore-hidden-footer)
  * [How to ignore copies from Universal Clipboard?](#how-to-ignore-copies-from-universal-clipboard)
* [Translations](#translations)
* [Motivation](#motivation)
* [License](#license)

<!-- vim-markdown-toc -->

## Features

### Core Foundation
* Lightweight and fast
* Keyboard-first navigation
* Secure and private
* Native macOS UI
* Open source and free

### v3 Multi-Source Architecture

* **Universal Content Sources**: Unified interface for clipboard, folders, and future content types
* **Dynamic Source Management**: Add/remove content sources on-demand with persistent configuration
* **Protocol-Oriented Design**: Scalable architecture supporting unlimited source types
* **Cross-Source Operations**: Select and combine content from any source type
* **Security-Scoped Access**: Secure folder monitoring with user-granted permissions

### Enhanced UI Features

* **Dynamic Tab System**: Tabs automatically appear for each registered content source
* **Aggregated View**: Special "#" tab showing selected items from all sources
* **Universal Item Interface**: Consistent UI for all content types
* **Folder Integration**: Native file picker for adding monitored directories
* **Real-time Updates**: Live content updates as files change

### Advanced Selection & Operations

* **Multi-select**: Select multiple items across different sources with checkboxes
* **Prompt mode**: Type instructions to combine with selected items
* **Combined operations**: Paste or copy multiple items with custom formatting
* **Cross-source selection**: Mix clipboard items with files seamlessly
* **Template system**: Customizable formatting for combined operations

### Enhanced Keyboard Navigation

* **Tab switching**: Navigate between different content sources
* **Universal shortcuts**: Consistent keyboard controls across all source types
* **Enhanced multi-select**: Tab to toggle selection, Cmd+N for nth item
* **Quick actions**: Immediate paste, copy, and preview operations

## Install

Download the latest version from the [releases](https://github.com/conmeara/nozzle/releases/latest) page, or use [Homebrew](https://brew.sh/):

```sh
brew install nozzle
```

## Usage

### Getting Started

1. **Open nozzle**: <kbd>SHIFT (⇧)</kbd> + <kbd>COMMAND (⌘)</kbd> + <kbd>C</kbd> or click the menu bar icon
2. **Navigate sources**: Use the dynamic tab bar to switch between clipboard, folders, and aggregated view
3. **Add folders**: Click the "+" tab to add monitored directories via file picker
4. **Search content**: Type to search within the active source
5. **Customize**: Access Preferences with <kbd>COMMAND (⌘)</kbd> + <kbd>,</kbd>

### Source Management

#### Clipboard Source
- **Access**: Default "Clipboard" tab shows clipboard history
- **Search**: Type to filter clipboard items
- **All traditional shortcuts**: Work exactly as before for backward compatibility

#### Folder Sources
- **Add folders**: Click "+" tab → select directory → automatic monitoring begins
- **Security**: Uses security-scoped bookmarks for persistent access
- **Updates**: Content refreshes when files change in monitored directories
- **Remove**: Use Preferences to manage registered folders

#### Aggregated View
- **Access**: "#" tab shows selected items from all sources
- **Cross-source**: Mix clipboard items with files seamlessly
- **Operations**: Perform combined actions on heterogeneous content

### Universal Item Operations

#### Selection
- **Toggle selection**: Click item checkbox or press <kbd>TAB</kbd> while highlighted
- **Multi-select**: Select items across different sources
- **Select by number**: <kbd>COMMAND (⌘)</kbd> + `n` toggles nth item selection
- **Clear selections**: <kbd>COMMAND (⌘)</kbd> + <kbd>DELETE (⌫)</kbd>

#### Actions
- **Copy item**: Click right side of item or <kbd>ENTER</kbd> on highlighted item
- **Paste item**: <kbd>OPTION (⌥)</kbd> + <kbd>ENTER</kbd> or <kbd>OPTION (⌥)</kbd> + click
- **Paste without formatting**: <kbd>OPTION (⌥)</kbd> + <kbd>SHIFT (⇧)</kbd> + <kbd>ENTER</kbd>
- **Preview**: <kbd>OPTION (⌥)</kbd> + <kbd>SPACE</kbd> or wait for tooltip
- **Delete** (clipboard only): <kbd>OPTION (⌥)</kbd> + <kbd>DELETE (⌫)</kbd>

### Advanced Multi-Source Features

#### Prompt Mode
1. **Switch modes**: <kbd>COMMAND (⌘)</kbd> + <kbd>F</kbd> toggles search ↔ prompt mode
2. **Type instructions**: In prompt mode, enter text to combine with selected items
3. **Combined paste**: <kbd>COMMAND (⌘)</kbd> + <kbd>V</kbd> pastes prompt + selected content
4. **Combined copy**: <kbd>COMMAND (⌘)</kbd> + <kbd>ENTER</kbd> copies combined content

#### Cross-Source Workflows
1. **Select from clipboard**: Toggle clipboard items in Clipboard tab
2. **Select from folders**: Toggle files in any folder tab
3. **View aggregated**: Switch to "#" tab to see all selections
4. **Combined operations**: Use prompt mode to combine with instructions

#### Template Customization
Default template combines prompt with selected items:
```
{prompt}
Context:
{items}
```

Customize the template:
```bash
defaults write org.p0deje.nozzle pasteTemplate "{prompt}\n\nSelected content:\n{items}"
```

## Advanced

### Content Source Management

#### Security-Scoped Bookmarks
nozzle v3 uses security-scoped bookmarks to maintain persistent access to user-selected folders:
- Bookmarks are stored securely in UserDefaults
- Access permissions persist across app restarts
- Folders are automatically restored on launch
- Stale bookmarks are cleaned up automatically

#### Adding Custom Sources
The v3 architecture supports extending with new content source types:
```swift
// Implement the ContentSource protocol
class CustomSource: ContentSource {
    let id: String
    let name: String
    let icon: NSImage
    let type: ContentSourceType
    // ... implement required methods
}

// Register with ContentManager
ContentManager.shared.registerSource(CustomSource())
```

### Clipboard Management

#### Ignore Copied Items
You can tell nozzle to ignore all copied items:

```sh
defaults write org.p0deje.nozzle ignoreEvents true # default is false
```

This is useful if you have some workflow for copying sensitive data. You can set `ignoreEvents` to true, copy the data and set `ignoreEvents` back to false.

You can also click the menu icon with <kbd>OPTION (⌥)</kbd> pressed. To ignore only the next copy, click with <kbd>OPTION (⌥)</kbd> + <kbd>SHIFT (⇧)</kbd> pressed.

### Ignore Custom Copy Types

By default nozzle will ignore certain copy types that are considered to be confidential
or temporary. The default list always include the following types:

* `org.nspasteboard.TransientType`
* `org.nspasteboard.ConcealedType`
* `org.nspasteboard.AutoGeneratedType`

Also, default configuration includes the following types but they can be removed
or overwritten:

* `com.agilebits.onepassword`
* `com.typeit4me.clipping`
* `de.petermaurer.TransientPasteboardType`
* `Pasteboard generator type`
* `net.antelle.keeweb`

You can add additional custom types using settings.
To find what custom types are used by an application, you can use
free application [Pasteboard-Viewer](https://github.com/sindresorhus/Pasteboard-Viewer).
Simply download the application, open it, copy something from the application you
want to ignore and look for any custom types in the left sidebar. [Here is an example
of using this approach to ignore Adobe InDesign](https://github.com/conmeara/nozzle/issues/125).

### Speed up Clipboard Check Interval

By default, nozzle checks clipboard every 500 ms, which should be enough for most users. If you want
to speed it up, you can change it with `defaults`:

```sh
defaults write org.p0deje.nozzle clipboardCheckInterval 0.1 # 100 ms
```

## FAQ

### Why doesn't it paste when I select an item in history?

1. Make sure you have "Paste automatically" enabled in Preferences.
2. Make sure "nozzle" is added to System Settings -> Privacy & Security -> Accessibility.

### When assigning a hotkey to open nozzle, it says that this hotkey is already used in some system setting.

1. Open System settings -> Keyboard -> Keyboard Shortcuts.
2. Find where that hotkey is used. For example, "Convert text to simplified Chinese" is under Services -> Text.
3. Disable that hotkey or remove assigned combination ([screenshot](https://github.com/conmeara/nozzle/assets/576152/446719e6-c3e5-4eb0-95fb-5a811066487f)).
4. Restart nozzle.
5. Assign hotkey in nozzle settings.

### How to restore hidden footer?

1. Open nozzle window.
2. Press <kbd>COMMAND (⌘)</kbd> + <kbd>,</kbd> to open preferences.
3. Enable footer in Appearance section.

If for some reason it doesn't work, run the following command in Terminal.app:

```sh
defaults write org.p0deje.nozzle showFooter 1
```

### How to ignore copies from [Universal Clipboard](https://support.apple.com/en-us/102430)?

1. Open Preferences -> Ignore -> Pasteboard Types.
2. Add `com.apple.is-remote-clipboard`.

## Translations

The translations are hosted in [Weblate](https://hosted.weblate.org/engage/nozzle/).
You can use it to suggest changes in translations and localize the application to a new language.

[![Translation status](https://hosted.weblate.org/widget/nozzle/multi-auto.svg)](https://hosted.weblate.org/engage/nozzle/)

## Motivation

### The Evolution to v3

nozzle began as an enhanced fork of Maccy, adding multi-select and prompt capabilities to clipboard management. However, as users' content workflows became more complex, it became clear that clipboard-only management was limiting.

**Why Multi-Source Architecture?**

Modern content workflows involve more than just clipboard history:
- Developers need quick access to code snippets stored in files
- Writers want to reference documents and notes alongside clipboard content
- Designers work with assets scattered across different locations
- Teams share content through various mediums

### The Universal Content Vision

nozzle v3 introduces a revolutionary approach: **treat all content sources equally**. Whether content comes from:
- Clipboard history
- File system directories  
- Future sources (notes, screenshots, cloud services)

They all use the same interface, selection system, and operations. This creates a truly unified content management experience that scales beyond traditional clipboard limitations.

### Technical Excellence

The v3 architecture showcases modern macOS development:
- Protocol-oriented design for infinite extensibility
- Swift 6 with @Observable for reactive UI
- Security-scoped bookmarks for persistent access
- MainActor isolation for thread safety
- SwiftUI + AppKit hybrid approach


## License

[MIT](./LICENSE)
