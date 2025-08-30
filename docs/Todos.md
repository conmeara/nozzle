

---

## Batch 2 — Panel & Modal Behavior (keep open, search mode stability)

### PR description

**Title:** Keep panel open during folder selection; prevent search-mode side effects on “+”

**Summary**

- Add `AppState.isModalInteractionActive`.
    
- Keep panel visible while `NSOpenPanel` is active.
    
- Ensure “+” does not toggle search mode or hide header buttons.
    

**Files to load**

- `nozzle/Observables/AppState.swift`
    
- `nozzle/Observables/Popup.swift`
    
- `nozzle/FloatingPanel.swift`
    
- `nozzle/Views/UnifiedInputFieldView.swift`
    
- `nozzle/Views/HeaderView.swift`
    

**Implementation**

- `AppState.isModalInteractionActive: Bool`.
    
- Before showing `NSOpenPanel`, set true; set false on completion.
    
- In `Popup`/`FloatingPanel`, guard auto-hide if `isModalInteractionActive`.
    
- Ensure “+” handler doesn’t mutate `isSearchMode`/focus; keep header buttons visible in search mode.
    

**Acceptance**

- Panel remains open during folder selection (cancel/approve).
    
- “+” doesn’t switch to search mode or hide UI buttons.
    

**Tests**

- UI: open/close panel → open picker; verify visibility and header buttons.
    

---

## Batch 3 — Selection & Aggregated View Parity

### PR description

**Title:** Selection parity + Cmd-Delete clears all + default preview to first item

**Summary**

- Map `⌘⌫` to clear selections and prompt text.
    
- Make file items in Aggregated highlight the same as clipboard items.
    
- On tab switch, preview/active item defaults to the first visible item.
    
- Fix selection/clip inconsistency to use `ContentManager.selectedItems`.
    

**Files to load**

- `nozzle/Observables/ContentManager.swift`
    
- `nozzle/Observables/AppState.swift`
    
- `nozzle/Views/AggregatedListView.swift`
    
- `nozzle/Views/UniversalListView.swift`
    
- `nozzle/Views/UniversalItemView.swift`
    
- `nozzle/Views/HistoryListView.swift`
    
- `nozzle/Views/KeyHandlingView.swift`
    

**Implementation**

- Keyboard: map `⌘⌫` → `ContentManager.clearSelection()`, `appState.history.clearSelection()`, `appState.promptText = ""`.
    
- Extract selection styling used by `HistoryItemView` into a shared style and apply in `UniversalItemView`.
    
- On `activeSourceId` change, set `appState.activeItemId` to first item in active source.
    
- Ensure copy/clip uses `ContentManager.selectedItems`.
    

**Acceptance**

- `⌘⌫` clears selections + prompt.
    
- Aggregated file items show the same selected appearance.
    
- Tab switch sets preview to the first item.
    
- Copy operates on centralized selections.
    

**Tests**

- Unit: `clearSelection` behavior & bridging.
    
- UI: highlight parity; first-item preview on tab switch.
    

---


## Batch 4 — Images in Aggregated List

### PR description

**Title:** Show image thumbnails in Aggregated & Universal lists

**Summary**

- Async thumbnail generation & caching for image files.
    
- Universal views render image preview (fallback placeholder).
    

**Files to load**

- `nozzle/Utilities/FileContentExtractor.swift`
    
- `nozzle/ApplicationImageCache.swift`
    
- `nozzle/Views/UniversalItemView.swift`
    
- `nozzle/Views/PreviewItemView.swift`
    

**Implementation**

- In extractor: detect image types → generate thumbnail off-main-thread; cache in `ApplicationImageCache`.
    
- `UniversalItemView`: render thumbnail when available; placeholder otherwise.
    
- Ensure MainActor updates and cancellation for offscreen items.
    

**Acceptance**

- Known image types show thumbnails in Aggregated/Universal lists.
    
- UI remains responsive.
    

**Tests**

- UI: large folder of images shows thumbnails without stutter.
    
---

## Batch 5 — Layout & Width Consistency

### PR description

**Title:** Make Aggregated view width consistent with other pages

**Summary**  
Normalize padding, icon sizes, and container frames so Aggregated width matches History/Universal lists.

**Files to load**

- `nozzle/Views/AggregatedListView.swift`
    
- `nozzle/Views/UniversalListView.swift`
    
- `nozzle/Views/HistoryListView.swift`
    
- `nozzle/Views/ContentView.swift`
    

**Implementation**

- Introduce shared layout constants; apply consistent list paddings and icon sizing.
    
- Remove any divergent min/max frames.
    

**Acceptance**

- Visual parity at identical window sizes.
    

**Tests**

- Visual/snapshot comparison.
    



---

## Batch 6 — Performance: Prioritize Content, Defer Previews

### PR description

**Title:** Defer heavy previews; prioritize list interactivity

**Summary**  
Move preview generation to background with throttling and cancellation; show placeholders immediately.

**Files to load**

- `nozzle/Views/PreviewItemView.swift`
    
- `nozzle/Utilities/FileContentExtractor.swift`
    
- `nozzle/Throttler.swift`
    
- `nozzle/ApplicationImageCache.swift`
    

**Implementation**

- Use `Task.detached(priority: .utility)` for heavy work + `Throttler`.
    
- Cancel tasks on item offscreen or selection change.
    
- Swap placeholder → preview when ready.
    

**Acceptance**

- Smooth scrolling & typing while previews load progressively.
    

**Tests**

- UI perf check with large directories.
    

---

## Batch 7 — Ignore Files: .gitignore + Per-user Patterns

### PR description

**Title:** Ignore patterns for FileSystemSource (.gitignore-like + user settings)

**Summary**  
Filter scans using default + user-defined patterns; expose UI in Ignore settings.

**Files to load**

- `nozzle/Observables/FileSystemSource.swift`
    
- `nozzle/Settings/IgnoreSettingsPane.swift`
    
- `nozzle/Extensions/Defaults.Keys+Names.swift` (or equivalent)
    

**Implementation**

- Simple glob/regex matcher; defaults: `.git`, `node_modules`, `DerivedData`, hidden files.
    
- Settings textarea: per-line patterns saved to Defaults.
    
- Apply filter during scan and FSEvents updates.
    

**Acceptance**

- Ignored paths never surface; toggling patterns re-scans.
    

**Tests**

- Unit: pattern coverage.
    
- UI: pattern edit updates list without restart.
    

---

## Batch 8 — UI Polish (tabs opacity, clear button move, checkmark animation, light-mode placeholder, remove clipboard metadata)

### PR description

**Title:** UI polish: tab opacity, prompt clear, clipboard confirmation, placeholders, metadata toggle

**Summary**

- Lower inactive tab opacity (Spotlight-like).
    
- Move “Clear instruction” into prompt text area (top-right overlay).
    
- On clipboard button press, show transient checkmark fade.
    
- Light-mode placeholder lighter (match dark-mode proportion).
    
- Hide clipboard metadata (default off; optional setting).
    

**Files to load**

- `nozzle/Views/ContentView.swift`
    
- `nozzle/Views/UnifiedInputFieldView.swift` (and/or `PromptHeaderView.swift`)
    
- `nozzle/Views/HistoryItemView.swift`
    
- `nozzle/Views/UniversalItemView.swift`
    

**Implementation**

- Adjust `.opacity()` on inactive tabs.
    
- Place “Clear” as overlay in prompt container.
    
- Animate `checkmark.circle.fill` on copy success.
    
- Use `.tertiary`/reduced opacity for placeholder in light mode.
    
- Add `Defaults.showClipboardMetadata` (false) to gate metadata view.
    

**Acceptance**

- All visual tweaks match description.
    

**Tests**

- Manual visual checks; quick snapshots if available.
    

---

## Batch 9 — Right‑click Menus + Sort By (folders)

### PR description

**Title:** Context menus everywhere + per-folder Sort By

**Summary**  
Audit/add `.contextMenu` on list rows; implement sort (Name/Date/Type, asc/desc) with per-source persistence.

**Files to load**

- `nozzle/Views/UniversalListView.swift`
    
- `nozzle/Views/FolderTreeItemView.swift`
    
- `nozzle/Observables/FileSystemSource.swift`
    

**Implementation**

- Right-click menu with: Open in Finder, Copy Path, Remove from Selection, Sort By → Name/Date/Type + Asc/Desc.
    
- `FileSystemSource` gains `sortMode` + `sortDescending`, apply after filtering/search; persist by `source.id`.
    

**Acceptance**

- Context menus present; sorting works and persists.
    

**Tests**

- Unit: sorters.
    
- UI: menu actions verified.
    

---

## Batch 10 — Search‑mode Robustness (buttons visible; “+” unaffected)

### PR description

**Title:** Keep header buttons visible in search; “+” action isolated from input focus

**Summary**  
Remove conditionals that hide buttons in search; ensure “+” doesn’t change focus or input mode.

**Files to load**

- `nozzle/Views/UnifiedInputFieldView.swift`
    
- `nozzle/Observables/AppState.swift`
    
- `nozzle/Views/HeaderView.swift`
    

**Implementation**

- Always render header buttons regardless of `isSearchMode`.
    
- Make “+” handler not modify search flags or focus.
    

**Acceptance**

- Buttons persist; clicking “+” does not alter search mode.
    

**Tests**

- UI: toggle search, verify buttons; click “+”, verify no mode change.
    
---

## Batch 11 — Shortcut Inventory & Optimization

### PR description

**Title:** Shortcut inventory, conflicts, and updates (incl. Cmd‑Delete)

**Summary**  
Enumerate all shortcuts, flag conflicts, add `⌘⌫` for “Clear all”, and align defaults with macOS conventions (Search `⌘F`, Copy `⌘C`, Paste Combined `⌘V`/`⌘⏎`, Add Folder `⌘N` if desired).

**Files to load**

- `nozzle/Extensions/KeyboardShortcuts.Name+Shortcuts.swift`
    
- `nozzle/KeyShortcut.swift`
    
- `nozzle/Views/KeyHandlingView.swift`
    
- `nozzle/Settings/ShortcutsSettingsPane.swift`
    

**Implementation**

- Produce a markdown list of current bindings (for release notes / docs).
    
- Add/route `⌘⌫` to clear selections + prompt.
    
- Adjust defaults to avoid conflicts; expose in settings.
    

**Acceptance**

- No duplicate chords in same scope; `⌘⌫` works.
    

**Tests**

- UI: verify each chord triggers a single action.
    


### Small items not explicitly covered above (roll into nearest batch)

- **Hover opacity in folders** → Batch 8 (polish).
    
- **Speed – Prioritize content view** → Batch 6 (perf).
    
- **Search mode deletes UI buttons** → Batch 10 (search-mode robustness).
    
- **.git ignore & user settings** → Batch 7 (ignore rules).
    
- **Aggregated width** → Batch 5 (layout).
    
- **Remove Metadata on clipboard** → Batch 8 (polish).
    
