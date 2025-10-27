import AppKit
import Defaults
import Foundation
import OSLog
import Settings
import UniformTypeIdentifiers

@Observable @MainActor
class AppState {
  static let shared = AppState()
  private static let logger = Logger(subsystem: "org.conmeara.nozzle.app", category: "AppState")
  private enum PasteDelays {
    static let clipboardSettle: UInt64 = 40_000_000 // 40 ms
    static let betweenItems: UInt64 = 100_000_000   // 100 ms
  }

  var appDelegate: AppDelegate?
  private let contentManager = ContentManager.shared
  var popup: Popup
  var history: History
  var footer: Footer

  var isPromptMode: Bool = true  // Default to prompt mode
  var promptText: String = "" {
    didSet {
      // Clear undo buffer if user manually edits after enhancement
      if originalPromptBeforeEnhancement != nil && 
         promptText != originalPromptBeforeEnhancement && 
         !isEnhancingPrompt {
        originalPromptBeforeEnhancement = nil
      }
    }
  }
  var isSearchMode: Bool = false  // Track search mode separately
  var showingShortcuts: Bool = false  // Track keyboard shortcuts panel visibility
  private var preservedSelections: Set<UUID> = []
  
  // Prompt enhancement state
  var isEnhancingPrompt: Bool = false
  var originalPromptBeforeEnhancement: String?
  
  // Undo the last prompt enhancement
  func undoEnhancement() {
    if let original = originalPromptBeforeEnhancement {
      promptText = original
      originalPromptBeforeEnhancement = nil
    }
  }
  
  // Check if undo is available
  var canUndoEnhancement: Bool {
    return originalPromptBeforeEnhancement != nil
  }
  
  // Prompt chips state
  var promptChips: [PromptChip] = [] {
    didSet {
      PromptChipsStore.save(promptChips)
      updateFooterItemVisibility()
      popup.needsResize = true
    }
  }
  // The chip that should be highlighted as active (only set on chip click)
  var activePromptChipId: UUID?
  
  // Notification to request focusing the input field from subviews
  static let focusInputNotification = Notification.Name("nozzle.focusInput")
  
  // Preview pane state management
  var showPreviewPane: Bool = Defaults[.showPreviewPane] {
    didSet {
      Defaults[.showPreviewPane] = showPreviewPane
    }
  }

  var previewPaneWidth: CGFloat = Defaults[.previewPaneWidth] {
    didSet {
      Defaults[.previewPaneWidth] = previewPaneWidth
    }
  }

  var previewItem: HistoryItemDecorator? {
    return history.selectedItem
  }
  
  var scrollTarget: UUID?
  var selection: UUID? {
    didSet {
      selectWithoutScrolling(selection)
      scrollTarget = isKeyboardNavigating ? selection : nil
    }
  }

  func selectWithoutScrolling(_ item: UUID?) {
    // Store previous selection for preview cleanup
    let previousItem = history.selectedItem
    
    // Update selectedItem for focus tracking (gray highlight)
    history.selectedItem = nil
    footer.selectedItem = nil

    if let itemDecorator = history.items.first(where: { $0.id == item }) {
      history.selectedItem = itemDecorator
      HistoryItemDecorator.showPreviewImmediately(for: itemDecorator)
    } else if let footerItem = footer.items.first(where: { $0.id == item }) {
      footer.selectedItem = footerItem
    }
    
    // Cancel preview for previously focused item if it changes
    if let previous = previousItem,
       previous.id != item {
      HistoryItemDecorator.previewThrottler.cancel()
      previous.showPreview = false
    }
  }

  var hoverSelectionWhileKeyboardNavigating: UUID?
  // Track which list row is currently hovered globally to avoid duplicate highlights
  var hoveredListItemId: UUID?
  var isKeyboardNavigating: Bool = true {
    didSet {
      if let hoverSelection = hoverSelectionWhileKeyboardNavigating {
        hoverSelectionWhileKeyboardNavigating = nil
        // Update the actual selection instead of the separate property
        selectWithoutScrolling(hoverSelection)
      }
    }
  }

  var searchVisible: Bool {
    if !Defaults[.showSearch] { return false }
    switch Defaults[.searchVisibility] {
    case .always: return true
    case .duringSearch: return !history.searchQuery.isEmpty
    }
  }

  var menuIconText: String {
    var title = history.unpinnedItems.first?.text.shortened(to: 100)
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    title.unicodeScalars.removeAll(where: CharacterSet.newlines.contains)
    return title.shortened(to: 20)
  }

  private var settingsWindowController: SettingsWindowController?

  init() {
    history = History.shared
    footer = Footer()
    popup = Popup()
    // Restore prompt chips
    promptChips = PromptChipsStore.load()
  }

  @MainActor
  func select() {
    if let item = history.selectedItem, history.items.contains(item) {
      history.select(item)
    } else if let item = footer.selectedItem {
      if item.confirmation != nil {
        item.showConfirmation = true
      } else {
        item.action()
      }
    } else {
      Clipboard.shared.copy(history.searchQuery)
      history.searchQuery = ""
    }
  }
  
  func togglePreview() {
    // Toggle the preview pane visibility
    showPreviewPane.toggle()
  }

  private func selectFromKeyboardNavigation(_ id: UUID?) {
    isKeyboardNavigating = true
    selection = id
    if let id {
      ContentManager.shared.focus(id)
    }
  }

  func highlightFirst() {
    if let item = history.items.first(where: \.isVisible) {
      selectFromKeyboardNavigation(item.id)
    }
  }

  func highlightPrevious() {
    isKeyboardNavigating = true
    if let selectedItem = history.selectedItem {
      if let nextItem = history.items.filter(\.isVisible).item(before: selectedItem) {
        selectFromKeyboardNavigation(nextItem.id)
      }
    } else if let selectedItem = footer.selectedItem {
      if let nextItem = footer.items.filter(\.isVisible).item(before: selectedItem) {
        selectFromKeyboardNavigation(nextItem.id)
      } else if selectedItem == footer.items.first(where: \.isVisible),
                let nextItem = history.items.last(where: \.isVisible) {
        selectFromKeyboardNavigation(nextItem.id)
      }
    }
  }

  func highlightNext() {
    if let selectedItem = history.selectedItem {
      if let nextItem = history.items.filter(\.isVisible).item(after: selectedItem) {
        selectFromKeyboardNavigation(nextItem.id)
      } else if selectedItem == history.items.filter(\.isVisible).last,
                let nextItem = footer.items.first(where: \.isVisible) {
        selectFromKeyboardNavigation(nextItem.id)
      }
    } else if let selectedItem = footer.selectedItem {
      if let nextItem = footer.items.filter(\.isVisible).item(after: selectedItem) {
        selectFromKeyboardNavigation(nextItem.id)
      }
    } else {
      selectFromKeyboardNavigation(footer.items.first(where: \.isVisible)?.id)
    }
  }

  func highlightLast() {
    if let selectedItem = history.selectedItem {
      if selectedItem == history.items.filter(\.isVisible).last,
         let nextItem = footer.items.first(where: \.isVisible) {
        selectFromKeyboardNavigation(nextItem.id)
      } else {
        selectFromKeyboardNavigation(history.items.last(where: \.isVisible)?.id)
      }
    } else if footer.selectedItem != nil {
      selectFromKeyboardNavigation(footer.items.last(where: \.isVisible)?.id)
    } else {
      selectFromKeyboardNavigation(footer.items.first(where: \.isVisible)?.id)
    }
  }

  @MainActor
  func openPreferences() { // swiftlint:disable:this function_body_length
    if settingsWindowController == nil {
      settingsWindowController = SettingsWindowController(
        panes: [
          Settings.Pane(
            identifier: Settings.PaneIdentifier.general,
            title: NSLocalizedString("Title", tableName: "GeneralSettings", comment: ""),
            toolbarIcon: NSImage.gearshape!
          ) {
            GeneralSettingsPane()
          },
          Settings.Pane(
            identifier: Settings.PaneIdentifier.storage,
            title: NSLocalizedString("Title", tableName: "StorageSettings", comment: ""),
            toolbarIcon: NSImage.externaldrive!
          ) {
            StorageSettingsPane()
          },
          Settings.Pane(
            identifier: Settings.PaneIdentifier.appearance,
            title: NSLocalizedString("Title", tableName: "AppearanceSettings", comment: ""),
            toolbarIcon: NSImage.paintpalette!
          ) {
            AppearanceSettingsPane()
          },
          Settings.Pane(
            identifier: Settings.PaneIdentifier.pins,
            title: NSLocalizedString("Title", tableName: "PinsSettings", comment: ""),
            toolbarIcon: NSImage.pincircle!
          ) {
            PinsSettingsPane()
              .environment(self)
              .modelContainer(Storage.shared.container)
          },
          Settings.Pane(
            identifier: Settings.PaneIdentifier.shortcuts,
            title: NSLocalizedString("Title", tableName: "ShortcutsSettings", comment: ""),
            toolbarIcon: NSImage(systemSymbolName: "command", accessibilityDescription: "Shortcuts")!
          ) {
            ShortcutsSettingsPane()
          },
          Settings.Pane(
            identifier: Settings.PaneIdentifier.ignore,
            title: NSLocalizedString("Title", tableName: "IgnoreSettings", comment: ""),
            toolbarIcon: NSImage.nosign!
          ) {
            IgnoreSettingsPane()
          },
          Settings.Pane(
            identifier: Settings.PaneIdentifier.advanced,
            title: NSLocalizedString("Title", tableName: "AdvancedSettings", comment: ""),
            toolbarIcon: NSImage.gearshape2!
          ) {
            AdvancedSettingsPane()
          }
        ]
      )
    }
    settingsWindowController?.show()
    settingsWindowController?.window?.orderFrontRegardless()
  }

  func quit() {
    NSApp.terminate(self)
  }
  
  func updateFooterItemVisibility() {
    // Find paste footer item
    if let pasteItem = footer.items.first(where: { $0.title == "paste_combined" }) {
      // Phase 2: Use centralized selection
      let hasSelected = !contentManager.selectedItems.isEmpty
      
      // Show this item only if we have selected items or prompt text
      let hasChips = !promptChips.isEmpty
      let hasContent = hasSelected || hasChips || !promptText.isEmpty
      pasteItem.isVisible = hasContent
    }
  }
  
  func clearSelectionAndPrompt() {
    // Preserve the current hover/active selection
    let currentSelection = selection
    
    // Clear all selected items across all sources
    contentManager.clearSelection()
    
    // Clear preserved selections
    preservedSelections.removeAll()
    
    // Clear prompt chips and text
    removeAllPromptChips()
    activePromptChipId = nil
    promptText = ""
    
    // Clear search query for the active source
    if contentManager.activeSourceId == "clipboard" {
      history.searchQuery = ""
    } else {
      contentManager.sources[contentManager.activeSourceId]?.searchQuery = ""
    }
    
    // Update footer visibility based on cleared state
    updateFooterItemVisibility()
    
    
    // Restore the hover/active selection
    if let currentSelection = currentSelection {
      selection = currentSelection
    }
  }
  
  func preserveCurrentSelections() {
    // Store currently selected items
    preservedSelections = Set(history.selectedItems.map { $0.id })
  }
  
  func restorePreservedSelections() {
    // Restore selections from preserved set
    for decorator in history.items {
      if preservedSelections.contains(decorator.id) {
        decorator.isSelected = true
      }
    }
  }
  
  @MainActor
  func performCombinedPaste() {
    // Use centralized selection from ContentManager, split into context and examples
    let contextSelectedItems = contentManager.selectedContextItems
    let exampleSelectedItems = contentManager.selectedExampleItems
    let hasPrompt = !promptText.isEmpty
    let hasSelectedItems = !(contextSelectedItems.isEmpty && exampleSelectedItems.isEmpty)
    
    guard hasPrompt || hasSelectedItems else { return }
    
    // Store current selection states and prompt text
    let currentPromptText = promptText
    
    // Capture original clipboard state before any operations
    let originalClipboardState = Clipboard.shared.captureClipboardState()
    
    // Capture clipboard content data early to avoid SwiftData context issues
    var clipboardContentCache: [UUID: [Clipboard.ClipboardContentData]] = [:]
    for item in (contextSelectedItems + exampleSelectedItems) where item.sourceType == .clipboard {
      if let historyDecorator = history.items.first(where: { $0.id == item.id }) {
        let contentData = historyDecorator.item.contents.map { content in
          Clipboard.ClipboardContentData(type: content.type, value: content.value)
        }
        clipboardContentCache[item.id] = contentData
      }
    }
    
    // Enable multi-paste mode to prevent clipboard monitoring (only for clipboard items)
    let hasClipboardItems = (contextSelectedItems + exampleSelectedItems).contains { $0.sourceType == .clipboard }
    if hasClipboardItems {
      Clipboard.shared.setMultiPasteMode(true)
    }
    
    // Close the popup immediately for better UX
    popup.close()
    
    // Separate text items from media items, preserving context vs examples
    let contextTextItems = contextSelectedItems.filter { !($0.imageData != nil || ($0.fileURL != nil && !$0.isText)) }
    let exampleTextItems = exampleSelectedItems.filter { !($0.imageData != nil || ($0.fileURL != nil && !$0.isText)) }
    let contextMediaItems = contextSelectedItems.filter { $0.imageData != nil || ($0.fileURL != nil && !$0.isText) }
    let exampleMediaItems = exampleSelectedItems.filter { $0.imageData != nil || ($0.fileURL != nil && !$0.isText) }
    
    // Execute the paste operations
    executeCombinedPaste(
      contextTextItems: contextTextItems,
      exampleTextItems: exampleTextItems,
      contextMediaItems: contextMediaItems,
      exampleMediaItems: exampleMediaItems,
      promptText: currentPromptText,
      hasClipboardItems: hasClipboardItems,
      originalClipboardState: originalClipboardState,
      clipboardContentCache: clipboardContentCache
    )
  }
  
  @MainActor
  private func executeCombinedPaste(
    contextTextItems: [ContentItem],
    exampleTextItems: [ContentItem],
    contextMediaItems: [ContentItem],
    exampleMediaItems: [ContentItem],
    promptText: String,
    hasClipboardItems: Bool,
    originalClipboardState: Clipboard.ClipboardSnapshot,
    clipboardContentCache: [UUID: [Clipboard.ClipboardContentData]]
  ) {
    let allMedia = contextMediaItems + exampleMediaItems

    Task { @MainActor in
      if !contextTextItems.isEmpty || !exampleTextItems.isEmpty || !promptText.isEmpty || !promptChips.isEmpty {
        let chips = self.promptChips
        let plain = await Task.detached(priority: nil) { () -> String in
          await CombinedContentBuilder.build(
            context: contextTextItems,
            examples: exampleTextItems,
            prompt: promptText,
            chips: chips
          )
        }.value

        Clipboard.shared.copyString(plain)
        try? await Task.sleep(nanoseconds: PasteDelays.clipboardSettle)
        Clipboard.shared.paste()
        try? await Task.sleep(nanoseconds: PasteDelays.betweenItems)
      }

      await self.pasteMediaItems(
        allMedia,
        index: 0,
        promptText: promptText,
        hasClipboardItems: hasClipboardItems,
        originalClipboardState: originalClipboardState,
        clipboardContentCache: clipboardContentCache
      )
    }
  }
  
  @MainActor
  private func pasteMediaItems(_ mediaItems: [ContentItem], index: Int, promptText: String, hasClipboardItems: Bool, originalClipboardState: Clipboard.ClipboardSnapshot, clipboardContentCache: [UUID: [Clipboard.ClipboardContentData]]) async {
    guard index < mediaItems.count else {
      // All operations complete, restore state
      await finalizeCombinedPaste(promptText: promptText, hasClipboardItems: hasClipboardItems, originalClipboardState: originalClipboardState)
      return
    }

    let item = mediaItems[index]

    // Skip folders - their contents are already captured in the selection
    if item.isFolder {
      // Move to next item without pasting
      await pasteMediaItems(mediaItems, index: index + 1, promptText: promptText, hasClipboardItems: hasClipboardItems, originalClipboardState: originalClipboardState, clipboardContentCache: clipboardContentCache)
      return
    }

    // Handle screenshot items with on-demand capture
    if item.sourceType == .screenshot {
      guard let screenshotSource = contentManager.sources[ScreenshotSource.sourceID] as? ScreenshotSource else {
        await pasteMediaItems(mediaItems, index: index + 1, promptText: promptText, hasClipboardItems: hasClipboardItems, originalClipboardState: originalClipboardState, clipboardContentCache: clipboardContentCache)
        return
      }

      if let capturedImage = await screenshotSource.captureScreenshot(for: item.id) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([capturedImage])

        try? await Task.sleep(nanoseconds: PasteDelays.clipboardSettle)
        Clipboard.shared.paste()
        try? await Task.sleep(nanoseconds: PasteDelays.betweenItems)
        await pasteMediaItems(mediaItems, index: index + 1, promptText: promptText, hasClipboardItems: hasClipboardItems, originalClipboardState: originalClipboardState, clipboardContentCache: clipboardContentCache)
      } else {
        // Screenshot capture failed - notify user and skip to next item
        Self.logger.error("Failed to capture screenshot for item: \(item.title)")
        NSSound.beep()
        await pasteMediaItems(mediaItems, index: index + 1, promptText: promptText, hasClipboardItems: hasClipboardItems, originalClipboardState: originalClipboardState, clipboardContentCache: clipboardContentCache)
      }
      return
    }

    // Copy content item to clipboard
    if let imageData = item.imageData, let image = NSImage(data: imageData) {
      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      pasteboard.writeObjects([image])
    } else if let fileURL = item.fileURL {
      // Handle both file-based items and clipboard items with file URLs
      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      pasteboard.writeObjects([fileURL as NSURL])
    } else if item.sourceType == .clipboard {
      // For clipboard items without fileURL, use cached content data
      // to avoid SwiftData context issues
      if let contentData = clipboardContentCache[item.id] {
        Clipboard.shared.copyContentData(contentData)
      }
    }

    try? await Task.sleep(nanoseconds: PasteDelays.clipboardSettle)
    Clipboard.shared.paste()
    try? await Task.sleep(nanoseconds: PasteDelays.betweenItems)
    await pasteMediaItems(mediaItems, index: index + 1, promptText: promptText, hasClipboardItems: hasClipboardItems, originalClipboardState: originalClipboardState, clipboardContentCache: clipboardContentCache)
  }
  
  @MainActor
  private func finalizeCombinedPaste(promptText: String, hasClipboardItems: Bool, originalClipboardState: Clipboard.ClipboardSnapshot) async {
    // Disable multi-paste mode (only if we had clipboard items)
    if hasClipboardItems {
      Clipboard.shared.setMultiPasteMode(false)
    }
    
    // Restore original clipboard content to prevent combined text from lingering
    Clipboard.shared.restoreClipboardState(originalClipboardState)
    
    // Only call this in the App Store version.
    AppStoreReview.ask()
    
    // Restore selections after a short delay to ensure UI is updated
    try? await Task.sleep(nanoseconds: PasteDelays.betweenItems)

    // Restore prompt text
    self.promptText = promptText

    // Phase 2: Selection is handled by ContentManager

    // Update footer visibility
    self.updateFooterItemVisibility()
  }
  
  // MARK: - Prompt chips helpers

  func addPromptChip(url: URL) {
    // Check if a chip with this URL already exists
    guard !promptChips.contains(where: { $0.url == url }) else {
      return // Don't add duplicates
    }
    
    let chip = PromptChip(url: url)
    promptChips.append(chip)
  }

  func removePromptChip(id: UUID) {
    promptChips.removeAll { $0.id == id }
  }

  func removeAllPromptChips() {
    promptChips.removeAll()
  }

  func requestFocusInput() {
    NotificationCenter.default.post(name: Self.focusInputNotification, object: nil)
  }

  func appendToInput(_ text: String) {
    // Append text to promptText with appropriate newline handling
    if promptText.isEmpty {
      promptText = text
    } else {
      // Add newline before appending if there's existing content
      promptText += "\n" + text
    }
    updateFooterItemVisibility()
  }

  // Update a prompt chip's URL after a rename while preserving its id
  func updatePromptChipURL(from oldURL: URL, to newURL: URL) {
    if let idx = promptChips.firstIndex(where: { $0.url == oldURL }) {
      let id = promptChips[idx].id
      var updated = promptChips
      updated[idx] = PromptChip(id: id, url: newURL)
      promptChips = updated
    }
  }
  
  // Enhance the current prompt using AI
  func performEnhancePrompt() {
    guard !isEnhancingPrompt else { return }
    
    // Set flag to prevent prompt editor from exiting if applicable
    ContentManager.shared.enhanceButtonClicked = true
    
    Task { @MainActor in
      let textToEnhance: String
      let isEnhancingEditor: Bool
      
      // Determine what text to enhance
      if ContentManager.shared.isPromptEditorEditing && !ContentManager.shared.promptEditorText.isEmpty {
        textToEnhance = ContentManager.shared.promptEditorText
        isEnhancingEditor = true
      } else if !promptText.isEmpty {
        textToEnhance = promptText
        isEnhancingEditor = false
      } else {
        ContentManager.shared.enhanceButtonClicked = false
        return
      }
      
      isEnhancingPrompt = true
      do {
        let enhanced = try await PromptEnhancer.shared.enhance(textToEnhance)
        if isEnhancingEditor {
          // Update prompt editor text
          ContentManager.shared.updatePromptEditorText(enhanced)
          // Also trigger a refresh in the editor by posting a notification
          NotificationCenter.default.post(name: .promptEditorTextUpdated, object: enhanced)
        } else {
          // Save original for undo support
          originalPromptBeforeEnhancement = promptText
          promptText = enhanced
        }
      } catch {
        // Handle error - could show alert or tooltip
        print("Enhancement error: \(error.localizedDescription)")
      }
      isEnhancingPrompt = false
      // Reset the flag
      ContentManager.shared.enhanceButtonClicked = false
    }
  }

}
