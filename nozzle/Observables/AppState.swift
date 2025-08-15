import AppKit
import Defaults
import Foundation
import Settings

@Observable @MainActor
class AppState {
  static let shared = AppState()

  var appDelegate: AppDelegate?
  var popup: Popup
  var history: History
  var footer: Footer

  var isPromptMode: Bool = true  // Default to prompt mode
  var promptText: String = ""
  var isSearchMode: Bool = false  // Track search mode separately
  private var preservedSelections: Set<HistoryItem> = []
  
  var scrollTarget: UUID?
  var selection: UUID? {
    didSet {
      selectWithoutScrolling(selection)
      scrollTarget = selection
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
  var isKeyboardNavigating: Bool = true {
    didSet {
      if let hoverSelection = hoverSelectionWhileKeyboardNavigating {
        hoverSelectionWhileKeyboardNavigating = nil
        selection = hoverSelection
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
    guard let item = history.selectedItem else { return }
    
    if item.showPreview {
      // Hide preview
      HistoryItemDecorator.previewThrottler.cancel()
      item.showPreview = false
    } else {
      // Show preview immediately for keyboard shortcut (no throttling)
      HistoryItemDecorator.showPreviewImmediately(for: item)
    }
  }

  private func selectFromKeyboardNavigation(_ id: UUID?) {
    isKeyboardNavigating = true
    selection = id
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
      // Show this item only if we have selected items or prompt text
      let hasContent = !history.selectedItems.isEmpty || !promptText.isEmpty
      pasteItem.isVisible = hasContent
    }
  }
  
  func clearSelectionAndPrompt() {
    // Preserve the current hover/active selection
    let currentSelection = selection
    
    // Clear all selected items
    history.items.forEach { $0.isSelected = false }
    
    // Clear preserved selections
    preservedSelections.removeAll()
    
    // Clear prompt text
    promptText = ""
    
    // Clear search query
    history.searchQuery = ""
    
    // Update footer visibility
    updateFooterItemVisibility()
    
    // Restore the hover/active selection
    if let currentSelection = currentSelection {
      selection = currentSelection
    }
  }
  
  func preserveCurrentSelections() {
    // Store currently selected items
    preservedSelections = Set(history.selectedItems.map { $0.item })
  }
  
  func restorePreservedSelections() {
    // Restore selections from preserved set
    for decorator in history.items {
      if preservedSelections.contains(decorator.item) {
        decorator.isSelected = true
      }
    }
    updateFooterItemVisibility()
  }
  
  @MainActor
  func performCombinedPaste() {
    let selectedItems = history.selectedItems
    let hasPrompt = !promptText.isEmpty
    let hasSelectedItems = !selectedItems.isEmpty
    
    guard hasPrompt || hasSelectedItems else { return }
    
    // Store current selection states and prompt text
    let selectedHistoryItems = selectedItems.map { $0.item }
    let currentPromptText = promptText
    
    // Enable multi-paste mode to prevent clipboard monitoring
    Clipboard.shared.setMultiPasteMode(true)
    
    // Close the popup immediately for better UX
    popup.close()
    
    // Separate text items from media items
    var textItems: [HistoryItemDecorator] = []
    var mediaItems: [HistoryItem] = []
    
    for item in selectedItems {
      if item.item.imageData != nil || !item.item.fileURLs.isEmpty {
        // Treat items with images or files as media
        mediaItems.append(item.item)
      } else {
        // Treat everything else as text (including items with no content)
        textItems.append(item)
      }
    }
    
    // Execute the paste operations
    executeCombinedPaste(
      textItems: textItems,
      mediaItems: mediaItems,
      promptText: currentPromptText,
      selectedHistoryItems: selectedHistoryItems
    )
  }
  
  @MainActor
  private func executeCombinedPaste(
    textItems: [HistoryItemDecorator],
    mediaItems: [HistoryItem],
    promptText: String,
    selectedHistoryItems: [HistoryItem]
  ) {
    // Step 1: Combine and paste all text content as one operation
    if !textItems.isEmpty || !promptText.isEmpty {
      let (rtf, html, plain) = combinedFormattedContent(from: textItems, promptText: promptText)
      Clipboard.shared.copyFormattedText(rtf: rtf, html: html, plain: plain)
      
      // Wait for clipboard update, then paste
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
        Clipboard.shared.paste()
        
        // Step 2: After text is pasted, paste media items sequentially
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          self.pasteMediaItems(mediaItems, index: 0, selectedHistoryItems: selectedHistoryItems, promptText: promptText)
        }
      }
    } else {
      // No text content, just paste media items
      pasteMediaItems(mediaItems, index: 0, selectedHistoryItems: selectedHistoryItems, promptText: promptText)
    }
  }
  
  @MainActor
  private func pasteMediaItems(_ mediaItems: [HistoryItem], index: Int, selectedHistoryItems: [HistoryItem], promptText: String) {
    guard index < mediaItems.count else {
      // All operations complete, restore state
      finalizeCombinedPaste(selectedHistoryItems: selectedHistoryItems, promptText: promptText)
      return
    }
    
    let item = mediaItems[index]
    Clipboard.shared.copy(item)
    
    // Wait for clipboard update, then paste
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
      Clipboard.shared.paste()
      
      // Wait before next media item
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        self.pasteMediaItems(mediaItems, index: index + 1, selectedHistoryItems: selectedHistoryItems, promptText: promptText)
      }
    }
  }
  
  @MainActor
  private func finalizeCombinedPaste(selectedHistoryItems: [HistoryItem], promptText: String) {
    // Disable multi-paste mode
    Clipboard.shared.setMultiPasteMode(false)
    
    // Only call this in the App Store version.
    AppStoreReview.ask()
    
    // Restore selections after a short delay to ensure UI is updated
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      // Restore prompt text
      self.promptText = promptText
      
      // Restore selections by matching the underlying HistoryItem
      for decorator in self.history.items {
        if selectedHistoryItems.contains(decorator.item) {
          decorator.isSelected = true
        }
      }
      
      // Also update preserved selections for when popup reopens
      self.preservedSelections = Set(selectedHistoryItems)
      
      // Update footer visibility
      self.updateFooterItemVisibility()
    }
  }
  
  private func combinedFormattedContent(from items: [HistoryItemDecorator], promptText: String) -> (rtf: Data?, html: Data?, plain: String) {
    let combined = NSMutableAttributedString()
    
    // Add prompt as plain text if present
    if !promptText.isEmpty {
      combined.append(NSAttributedString(string: promptText + "\n"))
    }
    
    // Add each item preserving its formatting
    for item in items {
      if let rtf = item.item.rtf {
        combined.append(rtf)
      } else if let html = item.item.html {
        combined.append(html)
      } else if let text = item.item.text {
        combined.append(NSAttributedString(string: text))
      }
      combined.append(NSAttributedString(string: "\n"))
    }
    
    // Return all formats - pasteboard will use the best available
    // Only convert to RTF/HTML if we have content to avoid crashes
    let plainText = combined.string
    let fullRange = NSRange(location: 0, length: combined.length)
    
    let rtfData: Data?
    let htmlData: Data?
    
    if combined.length > 0 {
      rtfData = try? combined.data(from: fullRange, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
      htmlData = try? combined.data(from: fullRange, documentAttributes: [.documentType: NSAttributedString.DocumentType.html])
    } else {
      rtfData = nil
      htmlData = nil
    }
    
    return (rtf: rtfData, html: htmlData, plain: plainText)
  }
  
}
