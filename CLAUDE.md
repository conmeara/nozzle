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

#Goals
Feature Changes:

1. Ability to paste multiple items from history
    - Checkboxes substitute the command shortcuts (Command-Number) next to each item in the clipboard history.
        - If Command key is held, the checkboxes turn into the command shortcuts again so users can quickly toggle clipboard history items.
    - If an item is checked/toggled, it highlights blue. 
2. Change the hover blue to a grey. 
    - This allows toggled items to be the blue and the user to understand where the hover or selection is at with grey color.
3. Prompt entry
    - Allows user to enter in a text prompt to be pasted in with the selected items.
    - Search bar will turn into the prompt entry.
        - Command-F turns the bar back into the search bar with the magnify glass signify

Shortcuts Changes:

Click - Item is selected/toggled
Command-Click - Item is Pasted
Enter on hover item - Item Pastes
Command-V - Pastes all selected items and prompt
Command-Enter - Pastes all selected items and prompt
Command - Shortcuts and numbers show

Footer Menu changes:

Paste - Command-V: Pastes all selected items and prompt
Copy to Clipboard - Command-Enter

Behavior changes:

- First item is automatically hover grey and 
- Selected items are selected blue

# Active Plan

## Extending Maccy with Multi-Select and Prompt Features

## 1. Multi-Item Selection UI and Logic

**Modify History Item View & Model:** In the current design, `History.selectedItem` enforces a single selection by toggling an item’s `isSelected` state exclusively. We will remove this one-at-a-time restriction and allow multiple items to be “selected” (checked) simultaneously. Each `HistoryItemDecorator` will act as its own selection source of truth with an `isSelected` (or new `isChecked`) flag that can be true for multiple items at once. The **`HistoryItemView`** (or similar list row view) will be updated to include a checkbox UI element (e.g. a SwiftUI `Toggle` styled as a checkbox) or a full-row click toggle:

* **Checkbox Display:** Add a checkbox control at the start of each history item row. In SwiftUI, this could be a `Toggle(isOn: $item.isSelected) { ... }` or a custom image indicating checked/unchecked state. We bind it to the item’s `isSelected` boolean so that checking it updates the model.

* **Row Highlight Colors:** Use two distinct highlight states:

  * **Blue (Selected):** If an item’s `isSelected` is true (checkbox checked), render its background with the system accent color (blue). This matches how the current single selection is highlighted (white text on blue).
  * **Gray (Hovered/Focused):** If an item is the current keyboard focus or hover target *but not checked*, render a gray background. We decouple “keyboard focus/hover” from “selected”. This means the first item on popup open will be auto-focused with a gray background (as before, using `appState.selection` to mark it) but will **not** be checked/blue until the user explicitly toggles it.

* **State Management:** Introduce a way to track the *focused* item separately from checked items. We will continue using `AppState.selection` (which holds the UUID of the item in focus) as the gray-highlight indicator. However, we will stop using `History.selectedItem` to mutate `isSelected` for focus changes. Instead, `History.selectedItem` can be repurposed or removed; the list rows will determine their background based on two conditions: `(item.isSelected)` for blue vs. `(item.id == appState.selection && !item.isSelected)` for gray. In SwiftUI, this can be done by extending the background binding logic. For example:

  ```swift
  .background(
    item.isSelected 
      ? Color.accentColor.opacity(0.8) 
      : (appState.selection == item.id ? Color.gray.opacity(0.2) : Color.clear)
  )
  ```

  The `.foregroundStyle` for text can remain white only for blue-selected items, and default for gray/clear backgrounds.

* **Toggle on Click:** Replace the current click behavior (which copies/pastes immediately) with selection toggling. Attach an `.onTapGesture` on the item row that checks for modifier keys:

  * If the **Command key is not held:** simply toggle the item’s `isSelected` state. For instance:

    ```swift
    .onTapGesture {
        if NSEvent.modifierFlags.contains(.command) {
            // handle Command-click separately (immediate paste)
        } else {
            item.isSelected.toggle()
            appState.selection = item.id  // move focus to this item
        }
    }
    ```

    Toggling sets `isSelected` true (item turns blue) or false (item unchecked). We also update `appState.selection` to this item so that keyboard navigation starts from here.
  * If the **Command key *is* held during click:** perform an immediate paste of that item instead of toggling (see Shortcut Handling below). This preserves a quick action for power users.

* **Keyboard Toggle (optional):** To support purely keyboard-driven multi-select, we can allow pressing **Space** to toggle the focused item. This would be implemented in the key handler (intercept space key when a history item is focused). Though not explicitly requested, it aligns with common multi-select UX.

* **Selection Persistence:** Maintain a collection of selected items. We can add `History.selectedItems: [HistoryItemDecorator]` (or simply compute it as `filter` of `items` where `isSelected=true`). This collection is used when executing the combined paste action (see Paste logic). No changes are needed to storage; selection is ephemeral UI state.

* **Prevent Conflicts:** With multiple selection, we ensure that moving the keyboard focus doesn’t inadvertently deselect items:

  * Remove or guard the `willSet` logic that automatically unchecks the previously selected item when `selection` changes. Instead, an item stays blue if checked until the user unchecks it, even if focus moves away.
  * Example: if the user checks item A, then arrow-down to item B (without toggling B), item A remains checked (blue) while item B is just gray-highlighted. The `HistoryItemView` will show A in blue (still selected) and B in gray.

* **UI Components Affected:**

  * `HistoryListView` (or equivalent): needs to allow multiple selection. If using a SwiftUI `List` or `ForEach` of items, set `.listStyle(.plain)` and enable multiple selection if it were AppKit (for SwiftUI, managing the state as above suffices).
  * `HistoryItemView` / `ListItemView`: add the checkbox and adjust its layout. Likely update `ListItemView` to include a leading checkbox. The row height may need slight increase to accommodate the checkbox comfortably.
  * **Hover Behavior:** We override hover highlight to gray. In the current code, onMouseMove toggles `appState.isKeyboardNavigating` and uses `selectWithoutScrolling` to select hovered items, which turned them blue immediately. We will change this: hovering should set `appState.selection` (for gray focus) *without* checking the item. Concretely, in the hover handler, call something like:

    ```swift
    if hovering {
        appState.isKeyboardNavigating = false
        appState.selection = item.id   // do not call selectWithoutScrolling to avoid isSelected side-effects
    }
    ```

    and ensure this does not flip the item’s `isSelected`. (If necessary, we might refactor `selectWithoutScrolling` to optionally not mark `isSelected`.)

* **First Item Auto-Hover:** On opening the window, we continue to auto-focus the first item. The difference is it will now be gray (since it’s focused but not yet checked). This happens because on appear we set `appState.selection` to the first item’s ID, but we will **not** mark it as `isSelected`. The UI logic then renders it with a gray background. *(If the current logic calls `history.selectedItem = firstItem` on open, we will need to stop that from auto-setting `isSelected`. Instead, perhaps directly set `appState.selection` and let the willSet of `selectedItem` no-op in multi-select mode.)*

* **Side Effects on Single-Item workflows:** Normal single-item selection/paste should still work:

  * Pressing **Enter** with one item focused (and none or one checked) will continue to copy that item (see Shortcut changes below). If multiple items are checked, we will likely override Enter to do nothing or just copy the focused item (to avoid ambiguity – instruct users to use the new combined paste shortcuts in that case).
  * The existing *pinned items* feature (items pinned to top with fixed shortcuts) continues to function. A pinned item can also be multi-selected like any other. (We’ll ensure that the random pin shortcut assignment does not use the `⌘V` key to avoid conflict – see below.)

## 2. Prompt Entry Mode (Search Bar vs Prompt Input)

**Dual Input Modes:** We introduce a **Prompt Entry Mode** that allows the user to type a multi-line prompt that will be included in the paste. The UI will toggle between the existing single-line *search field* and a new *multi-line prompt text area*. Key points:

* **Mode Toggle Shortcut:** Bind **⌘F** to switch modes. (⌘F is free in Maccy since search is always visible; this will explicitly let the user switch to prompt input.) We will intercept `⌘+F` in the key handler and toggle a state flag (e.g. `appState.isPromptMode`). For example, in the key event handling:

  ```swift
  case .findPromptToggle: 
      appState.isPromptMode.toggle()
      return .handled
  ```

  (We would add a new `KeyChord` case or a custom check for `⌘F` before the default handling, since currently ⌘F is not mapped.)

* **UI Layout:** In **ContentView**, conditionally display either the search bar or the prompt field. For example:

  ```swift
  if !appState.isPromptMode {
      HeaderView(searchQuery: $appState.history.searchQuery, searchFocused: $searchFocused)
  } else {
      PromptHeaderView(promptText: $appState.promptText, promptFocused: $promptFocused)
  }
  ```

  The `PromptHeaderView` would be a new `View` containing a multi-line `TextEditor` bound to `appState.promptText`. It should have a similar style/placement as the search bar (at the top of the popup), but allows vertical expansion for multiple lines. We might give it a slightly larger fixed height or make it dynamically resize with content. For simplicity, a fixed height for a few lines (with scroll for overflow) can be used.

* **Focus Handling:** When entering prompt mode, we want the prompt `TextEditor` to be focused so the user can immediately type. We introduce something like `@FocusState var promptFocused: Bool` and set it to true on mode activation (and conversely refocus search field when leaving prompt mode). This ensures a smooth toggle:

  * After toggling to prompt mode, programmatically focus the prompt editor (and maybe clear any placeholder text).
  * On toggling back to search mode, refocus the search field (and possibly clear or restore the last query as needed).

* **Search vs Prompt Behavior:**

  * In **search mode** (`isPromptMode == false`), the search field behaves exactly as before: typing filters the history list in realtime (`history.searchQuery` drives `isVisible` for items).
  * In **prompt mode** (`isPromptMode == true`), the search field is hidden and the list is no longer being filtered by new input. The history list would typically show the last filter’s results or all items. We will *retain the previous search results* when switching to prompt mode (i.e. do not clear `searchQuery` on mode switch). This way a user can search for items first, then hit ⌘F to switch to prompt input while those filtered items remain in view for selection.

    * If needed, we can lock the filtering: we might disable live updating of `history.searchQuery` while in prompt mode to avoid any accidental filtering if the user types something that could be interpreted as search. (Since the search field is hidden, this is moot unless some code is still updating it.)
    * Alternatively, we set `searchFocused=false` which stops capturing keystrokes for search.

* **Prompt Field Properties:**

  * The prompt input should support **multiple lines**. A SwiftUI `TextEditor` is appropriate. We bind it to a new `@Observable` property `AppState.promptText: String` (initially empty).
  * Design the prompt field UI to be minimal (perhaps a subtle border or background to indicate an input area). Possibly reuse the style of the search field but multiline.
  * Provide a placeholder text like *"Type prompt (optional)..."* to guide the user when empty. (Implement by overlaying a `Text` when `promptText.isEmpty` since `TextEditor` doesn’t have a built-in placeholder.)

* **Integration with Paste Schema:** The content of `promptText` will be used as `{Prompt}` in the paste template (see next section). If the user leaves it blank, the final pasted format should omit it (we’ll handle formatting accordingly).

* **Exiting Prompt Mode:** The user can hit ⌘F again to go back to search mode. We do *not* automatically clear the prompt text on exit; we will keep whatever was typed in case they toggle back (unless the window closes, in which case we can reset it). When the popup closes (after a paste or manually), we should clear `promptText` for next time to avoid stale data.

* **UI Components Affected:**

  * `HeaderView` (the search bar container) will be augmented or complemented by a new `PromptView`. We might integrate this into the existing `HeaderView` as an overlay that appears when `appState.isPromptMode` is true, or simply use an `if` as shown above in the parent container.
  * Layout adjustments: The prompt field will likely be taller than the 25px search bar. We may allow the window to grow vertically when in prompt mode. The `FloatingPanel` resizing logic can accommodate this by observing the content size. (If needed, adjust `appState.popup.headerHeight` calculation to account for the prompt field height similarly to how it does for search.)

* **Data Model:** Add `promptText: String` to `AppState` (or to a new model struct if preferred). Mark it with @Observable or @Published so the UI updates as user types and so we can easily retrieve it for the paste operation.

* **Scene Phase & Clearing:** If Maccy window loses focus or closes, ensure `promptText` is reset to `""` (similar to how searchQuery is cleared on close by the existing code). We might piggyback on the same mechanism that clears search on selection or hide, e.g. after a combined paste, do `appState.promptText = ""`.

## 3. Paste Schema Formatting and Execution

When the user triggers the **“paste combined”** action (via shortcut or footer button), Maccy will gather the prompt and selected items and format them into a single block of text to copy/paste. The format is:

```
{Prompt}
Context:
{Selected Item 1}
{Selected Item 2}
...
```

We will make this **schema customizable** via preferences, but the default corresponds to the above. Implementation details:

* **Collecting Selected Items:** In the paste handler, retrieve the list of all items currently selected (checked). For example, `let items = history.items.filter { $0.isSelected }`. We will use their full text content. Each `HistoryItemDecorator` likely contains the string content (e.g. `item.item.string` or `item.title` for plain text). For items that were rich text or images, we may need to decide how to handle them: initially we can use their plain-text representation (`item.title`) since combining binary data or multiple formats is nontrivial. (This is an area to document: combining images is not explicitly handled – possibly out of scope.)

* **Retrieving Prompt:** Get the current `promptText` from `AppState`. This is a plain string (could be multi-line, as entered).

* **Template Formatting:** Load the user-defined template from preferences. We’ll add a new user-defaults key, e.g. `Defaults.Key<String>("pasteTemplate", default: "{prompt}\nContext:\n{items}")`. In Preferences UI, provide a text field for “Paste Format” where users can include placeholders:

  * `{prompt}` (or perhaps `%prompt%`) for the prompt text.
  * `{items}` for the concatenated selected items.
    We will document that `{items}` will insert all selected items, each on a new line (the app will join them with newline by default). Advanced formatting per item (like numbering or bulleting) is not directly supported except by what the static template contains around `{items}`.

* **Combining Text:** Generate the combined text according to the template:

  * Start with the template string (default or user-modified).
  * Replace `{prompt}` token with the prompt text. If the prompt is empty, we can replace it with an empty string (and possibly remove any trailing newlines or the "Context:" label if desired – see below).
  * Replace `{items}` with the joined selected items text. For joining, we typically use `"\n"` as separator (or `"\n\n"` if we want a blank line between items – the default example shows each item on its own line under "Context:").

    ```swift
    let selectedTexts = items.map { $0.contentString }  // get text from each item
    var output = template
       .replacingOccurrences(of: "{prompt}", with: promptText)
       .replacingOccurrences(of: "{items}", with: selectedTexts.joined(separator: "\n"))
    ```
  * Handle edge cases: If `promptText` is empty, the output might start with a blank line before "Context:". We can choose to trim it. For example, if prompt is empty, perhaps we remove the "Context:" label as well. This could be achieved by checking if `{prompt}` is in template and if promptText is empty:

    ```swift
    if promptText.isEmpty {
        // Remove or adjust the "Context:" line if present in template
        output = output.replacingOccurrences(of: "\nContext:\n", with: "") 
    }
    ```

    This ensures that if no prompt was provided, we don't leave an orphan "Context:" at top. (This behavior can be refined or made optional.)

* **Performing the Paste or Copy:**

  * If the user invoked **Paste (⌘V)**, we will:

    1. Copy the `output` text to the clipboard.
    2. Immediately issue a paste command to the frontmost application.
    3. Close the Maccy window.
       This mirrors how Maccy pastes a single item with Option+Enter: it copies to clipboard and then calls `Clipboard.shared.paste()`. We will use the same utility:

       ```swift
       Clipboard.shared.copy(output)       // copy combined text to NSPasteboard
       Clipboard.shared.paste()           // simulate Cmd+V in active app (requires accessibility permission)
       appState.popup.close()            // close the Maccy panel
       ```

    (We assume `Clipboard.shared.copy(_:)` can take a raw string for combined content. If it expects a `HistoryItem` object, we may need to create a temporary HistoryItem for the combined text. A simpler approach is to extend `Clipboard` with a method to copy raw strings.)

    * Note: Ensure `Clipboard.shared.copy` uses `removeFormatting: false` so that formatting is preserved if needed (we likely treat the output as plain text though).
  * If the user invoked **Copy to Clipboard (⌘⏎)**, we will:

    1. Copy the `output` text to clipboard (without pasting).
    2. Close the Maccy window.
       This is analogous to pressing Enter normally (copy). We can call `Clipboard.shared.copy(output)` and close.
  * After either action, consider adding the combined output as a new entry in history (optional). This could be useful if the user frequently reuses the same combination. We might add it to history so it can be accessed later. This could be done by inserting a new `HistoryItem` into storage. However, since the question doesn’t explicitly request it, we can omit this or make it a preference (it might clutter history for some). We will note it as a consideration.

* **Preferences UI:** In the Preferences window (likely under an “Advanced” or new “Formatting” section), add a field for the paste template. For example:

  * Label: "Combined Paste Format"
  * A multiline text field pre-filled with the default pattern:

    ```
    {prompt}
    Context:
    {items}
    ```

    Possibly provide a tooltip or documentation that `{prompt}` is replaced by the Prompt text, and `{items}` by the list of selected items. The user can include other text or newline as desired.
    We integrate this with the Defaults system so that changes update `Defaults[.pasteTemplate]`. The paste logic will fetch this each time.

* **Resilience:** If no items are selected when the user triggers the combined paste, we should safely no-op or handle it. Likely, the menu item/shortcut will be disabled unless at least one item is checked:

  * We can disable the **Paste** and **Copy** footer actions if nothing is selected (see Footer below).
  * If somehow triggered with none selected, just close the window without doing anything (or beep).

* **Non-Text Data:** All selected items will be pasted as text. If some history items were images or files, their textual representation (if any) will be used. This means the feature is primarily targeted at text content. We should clarify in documentation that combining non-textual clip types may not behave as expected. (Possible future improvement: if multiple images are selected, maybe create an RTF/HTML that includes them or paste sequentially – but this is complex and beyond scope.)

* **Potential Side Effect:** The combined paste will paste all items in quick succession within the active app. For most text fields, this results in one block of text (with newlines) which is what we want. In edge cases (e.g. pasting into separate form fields), the newline separation might move focus – but since we simulate a single clipboard paste event, most applications will insert the text exactly as formatted.

## 4. Shortcut Handling and Footer Actions

We need to introduce new keyboard shortcuts and clickable footer buttons for the multi-paste feature, and adjust existing shortcuts for consistency:

* **Immediate Paste on Command-Click:** As noted above, a **⌘-Click** on a history item will bypass multi-selection and paste that single item immediately. This effectively replaces the old Option-click behavior with Command-click:

  * In the item row `.onTapGesture` handling, we check `if NSEvent.modifierFlags.contains(.command)` (or use the `modifierFlags` environment) and if so, execute:

    ```swift
    Clipboard.shared.copy(item.item) 
    Clipboard.shared.paste()
    appState.popup.close()
    ```

    which will instantly paste that item’s content. This uses the same logic as history.select with `.paste` action. We should also respect the “paste without formatting” if Shift is pressed as well (e.g. ⌘+Shift+Click could paste without formatting – if we want to preserve that feature). We can detect `.shift` in modifier flags and use `Clipboard.shared.copy(item.item, removeFormatting: true)` in that case.
  * Rationale: This provides a quick one-click paste while in multi-select mode, without having to uncheck others first. It also aligns with using Command as the “fast action” modifier.

* **Command-Number Shortcuts (Fast Access):** We will **retain** the existing **⌘+1…9** shortcuts to quickly select items by index. When the Command key is held, the UI already shows the shortcut hints next to items. We do not disable this – instead, we make sure that if the user is holding ⌘ (intending to use number shortcuts), we do not interpret number key presses as typing or selection toggles:

  * In practice, our implementation above doesn’t assign any new meaning to number keys without Command (they would just go into the search field or do nothing). So the existing mechanism stands: holding ⌘ and pressing *n* triggers `pressedShortcutItem` in the key handler to select that item. This will **copy** that item to clipboard (since by default ⌘+n is treated like pressing Enter on that item – no paste unless Option is also held).
  * **When ⌘ is held, do not toggle checkboxes on key press.** (No change needed, since toggling is only on click or maybe spacebar).
  * We should ensure that having items already checked doesn’t interfere – it won’t, because the number shortcut selection will close the window immediately (user choosing a specific item cancels the multi-select workflow). Checked states can be left as-is (they’ll be cleared when window closes, since we’ll reset `isSelected` on reopen).

* **Command+Enter and Command+V Shortcuts:**

  * **⌘+V** while the Maccy window is open will trigger the *Paste All* action. Normally, pressing ⌘V would attempt to paste into the search field (because it’s a standard Paste shortcut in a text field). We will intercept it at the application level:

    * In `KeyHandlingView.onKeyPress`, before the main switch, detect if the current event corresponds to the **system paste shortcut**. We can utilize `KeyChord.pasteKey` and `pasteKeyModifiers` (which reflect the system’s paste menu item, usually ⌘ and key "V"). For example:

      ```swift
      if let event = NSApp.currentEvent,
         event.keyCode == KeyChord.pasteKey.code &&    // pseudo-code: compare key
         event.modifierFlags.intersection(...)==KeyChord.pasteKeyModifiers {
           appState.performCombinedPaste() 
           return .handled
      }
      ```

      (We might need to extend `KeyChord` or use a simpler check since we know it's ⌘+V in most cases.)
    * Mark it handled so it doesn’t propagate to the search field.
    * `appState.performCombinedPaste()` will execute the logic from section 3 (copy all selected + prompt, paste to app, close window).
    * **Conflict resolution:** We must ensure this overrides any pinned item shortcut that might also be ⌘V. By default, pinned items get a random letter assigned for ⌘ shortcuts. We should avoid 'V' as a pin shortcut. One approach is to filter out the system paste key when generating pin shortcuts. (If not, our key handler check for ⌘V should run *before* pressedShortcutItem. We will place the ⌘V trap at the top of `.onKeyPress` so that even if an item had 'V' as its shortcut, the combined paste takes priority.)
  * **⌘+Enter** will trigger the *Copy All to Clipboard* action:

    * We add a similar check in the key handler for the Return/Enter key with Command. Recall that in `KeyChord`, any Enter (Return) with any modifiers currently maps to `.selectCurrentItem`. This means pressing ⌘Enter would ordinarily invoke the same path as Enter alone (copying the focused item). We need to override this when multiple selection is in play.
    * Strategy: If multiple items are selected (or prompt text is non-empty), interpret ⌘Enter as “copy all”:

      ```swift
      if event.key == .return && event.modifierFlags.contains(.command) {
          if !history.selectedItems.isEmpty {
              appState.performCombinedCopy()   // copy combined output, close window
              return .handled
          }
          // else, fall through to normal handling (copy single item)
      }
      ```

      We insert this check before the KeyChord switch or within it by refining the `.selectCurrentItem` case logic. Another option is to extend `HistoryItemAction` or `KeyChord` to differentiate ⌘Enter when multiple items are selected. Simpler is the direct check as shown.
    * `performCombinedCopy()` would assemble the text and copy to clipboard, then close, without issuing a paste.
    * If no items are multi-selected (and prompt is empty), ⌘Enter could simply behave like regular Enter (copy current item). But since regular Enter does that anyway, we might not need to do anything in that scenario. It’s fine for ⌘Enter to duplicate the action of Enter when no multi-select is in use, or we can leave it to fall through to the existing `.selectCurrentItem` handling (ensuring our check does nothing if `selectedItems` is empty).
    * We should also intercept **Option+⌘+Enter** if we want ⌘+Enter to consistently mean "copy combined" even if user also holds Option. However, Option+⌘+Enter is not a likely combo to press by accident, and we haven’t assigned it any meaning. For clarity, we can decide ⌘+Enter always does combined copy, ignoring Option. (If someone did hold Option as well, `modifierFlags.contains(.command)` will still be true and we’ll handle it; any Option in the flags doesn’t need special case here.)

* **Footer Buttons:** Add two new entries to the footer menu for mouse access:

  * **“Paste” (⌘V)** and **“Copy to Clipboard” (⌘↩)**. These will appear at the bottom of the popup window, in the footer section (below “Clear”). We append them to `footer.items` so that `FooterView` renders them in the list. For example, in `Footer` model initialization, do something like:

    ```swift
    items.append(Footer.Item(title: "paste_combined", text: "Paste", 
                 shortcuts: [KeyShortcut(.v, modifiers: .command)], action: { performCombinedPaste() }))
    items.append(Footer.Item(title: "copy_combined", text: "Copy to Clipboard", 
                 shortcuts: [KeyShortcut(.return, modifiers: .command)], action: { performCombinedCopy() }))
    ```

    Each `FooterItem` should have:

    * a unique identifier/title (e.g. `"paste_combined"` for internal logic, and `"copy_combined"`),
    * a display text (likely localized) for “Paste” and “Copy to Clipboard”,
    * a keyboard shortcut representation (so the UI can show “⌘V” or “⌘↩” on the right side, similar to how Clear shows its shortcut).

      * We will use `.v` with `.command` for Paste, and `.return` with `.command` for Copy. The `KeyboardShortcutView` in `ListItemView` will automatically display these when the Command key is held. So when the user holds ⌘, they’ll see “V” next to the Paste footer item and “↩” next to Copy, indicating those shortcuts.
    * an `action` closure that invokes the appropriate combined operation.

  * **FooterView Display:** Because we added these after the first two items (Clear/ClearAll), `FooterView` will list them below the divider:

    * The first line of the footer remains the Clear/Clear All toggle in the ZStack.
    * Then the ForEach will iterate over items 2 onward, which will now include our “Paste” and “Copy” items (and possibly any other future items). They will be shown as separate lines with their labels and shortcuts.

  * **Enable/Disable logic:** Ideally, the Paste/Copy footer items should only be enabled (visible or active) when the action is applicable (i.e. when there is something to paste or copy). We can use the `isVisible` or similar property on `FooterItem` if it exists:

    * For instance, set `footer.items[2].isVisible = (history.selectedItems.count > 0)` and similarly for the Copy item. We can update this whenever the selection changes:

      * When an item’s checkbox toggles, after updating `isSelected`, set these flags accordingly. (If `FooterItem.isVisible` is observed, the SwiftUI view will hide/show).
      * Alternatively, always show them but allow their action even if nothing selected (which would just copy an empty prompt or do nothing). Better UX is to disable or hide. Since FooterView already toggles Clear vs Clear All, it supports dynamic visibilities.
      * Simpler: we might always show the buttons but if pressed with nothing selected, just copy/paste only the prompt or nothing. However, that could confuse the user if they accidentally hit it with no selection. So disabling is preferred.
    * If `FooterItem` has an `isEnabled` property, we could use that to gray them out. If not, we can manage via `isVisible` similarly. (From FooterView code, it appears they toggle Clear and Clear All by switching visibility and opacity.)
    * Implementation: e.g.

      ```swift
      footer.items[2].isVisible = !history.selectedItems.isEmpty
      footer.items[3].isVisible = !history.selectedItems.isEmpty
      ```

      and possibly also `isVisible = true` if prompt is non-empty even with no items (the user might want to paste just a prompt with no context – our format could allow that). We can decide that at least one of prompt or items should be non-empty to enable. For safety, treat prompt as part of the content, so if prompt is filled and no items checked, the user could still hit Paste to insert just the prompt (and the "Context:" line would be removed by our formatting logic). So enable if `(promptText != "" || !selectedItems.isEmpty)`.
    * We will update these flags on every toggle of a history item and when prompt text changes from empty to non-empty (and vice versa). This can be done via simple observers or within the SwiftUI bindings.

  * **Footer Actions Execution:** When the user clicks the footer “Paste” button, it should perform the same as pressing ⌘V (combined paste). We set the `action` to call the same logic:

    ```swift
    footer.items[2].action = { [weak self] in self?.performCombinedPaste() }
    ```

    Similarly for Copy. The `AppState.select()` method already checks if a footer item is selected and calls its `action`. So when the user presses Enter while a footer item is focused, or clicks it, the action will execute.

    * We should ensure these new footer items have `confirmation = nil` (no confirmation dialogs) so they execute immediately.
    * The `help` text can be left nil or given a description (help appears as tooltip, likely not necessary here).

* **Adjusting Existing Shortcuts Display:** Since we changed the meaning of Option-click to Command-click for instant paste, the on-screen hints for shortcuts might need adjusting:

  * The menu bar help/README should be updated to reflect “⌘-Click = Paste immediately” instead of Option-click. (The question doesn’t ask for documentation, but we should be mindful of user cues.)
  * In the UI, the keyboard shortcut hints next to each item currently show one primary shortcut (the number or letter). For Option shortcuts, the app didn’t display “⌥number” on items, it just shows the base shortcut (the number) and users learn that Option modifies it to paste. With our new approach, we similarly rely on user knowing that holding ⌥ applies paste by default (if they enabled that) or ⌘Click does paste. It might not explicitly show “⌘” on the item. However, since we’re using ⌘ for multi-select toggling and for showing numbers, continuing to hide Option hints is okay.
  * The footer items explicitly display their ⌘ shortcuts when ⌘ is pressed (the code shows they appear with opacity 1 then). That should just work for our new items.

* **No Regression in Old Behavior:**

  * **Option+Number/Enter:** We have not removed the Option-based shortcuts. Users who still press Option+1 or Option+Enter will trigger the old code path of immediate paste of that single item. This remains functional. It means there are technically two ways to paste one item (Option+Enter and our new Cmd+Click or selecting and pressing Cmd+V with just one item). This redundancy is acceptable. We may mention in release notes that Command can be used as an alternative to Option for those actions.
  * **Pin/Unpin & Delete:** These should continue working on the *focused* item (the one with gray highlight). For example, if multiple are selected and the user presses ⌥⌫ (delete shortcut), the code will delete `history.selectedItem` (which is the focused item). We are not enabling bulk delete in this feature, so that’s fine – only the highlighted item will delete. Similarly, pin/unpin (⌥P) acts on the highlighted item. This is a known limitation (no multi-pin or multi-delete yet). We should ensure that if a pinned item is checked, pin/unpin toggling it doesn’t erroneously affect selection states (shouldn’t; it just moves item in list).
  * **Auto-Clear Search:** Currently, after selecting an item (copying/pasting), Maccy clears the search query and closes. We will do similar for prompt mode: after a combined paste or copy, we close the window and reset state. On next open, the search field is empty (unless pinned items show, etc.) and prompt mode off. We should also clear all `isSelected` flags on history items when closing, so that next time the history list has no leftover checked items. This can be done by iterating `history.items.forEach { $0.isSelected = false }` either when closing or on next open. (Alternatively, since we reinitialize the list on load, that might naturally reset in-memory flags, but we’ll explicitly ensure it.)

By implementing these changes, we touch all relevant parts of the app: the model (allow multi-select), the view (checkboxes and prompt field), the controller logic (keyboard and click handling), and preferences. We carefully maintain backward-compatible behavior where sensible, while introducing the new multi-item paste workflow:

* **Summary of Key Architectural Decisions:** We chose to represent multi-selection at the **model level on each item** (`isSelected` flag) rather than maintaining a separate list in AppState alone, because this leverages SwiftUI’s reactivity on each item and simplifies highlighting logic. We introduced a **prompt model** in AppState to manage the new input mode globally. The view-controller separation is preserved: the SwiftUI views remain relatively declarative (they read from AppState and item states), while the AppState/History handle the logic of selection toggling and executing paste operations. We intercept new shortcuts at the key event layer (via `KeyHandlingView`) to integrate with the existing shortcut parsing . The **Footer** acts as a mini-controller for actions; adding new Footer items with bound actions keeps the design consistent and avoids special-case code in the key handler for those actions (the handler simply calls the same `performCombinedPaste/Copy` functions that footer actions call).

Overall, these modifications extend Maccy to support an “assemble and paste” workflow (useful for AI prompts and other multi-copy tasks) while keeping existing quick single-item usage intact. All new strings (“Paste”, “Copy to Clipboard”, “Context:”, etc.) will be added to localization files as needed, and we will update the README/Help to document the new shortcuts.

**Sources:**

* Maccy selection model uses a single `selectedItem` with an `isSelected` flag and UI highlights selected items in accent color. We modify this to allow multiple `isSelected` true concurrently and introduce a gray highlight for the focused item.
* Key handling currently maps ⌘+number to direct selection and Enter to item selection (copy/paste). We extend this to intercept ⌘V and ⌘Enter for combined actions and preserve number shortcuts.
* The Clipboard copy/paste utility is used to implement immediate paste (copy then `paste()` for Option-click/Enter). We reuse this for combined pasting of multiple items.
* Footer items are listed in `footer.items` and rendered in FooterView. We append “Paste” and “Copy” buttons to this list with appropriate shortcuts and actions.
