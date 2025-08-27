import AppKit
import Defaults
import Foundation
import Settings
import UniformTypeIdentifiers

@Observable @MainActor
class AppState {
  static let shared = AppState()

  var appDelegate: AppDelegate?
  private let contentManager = ContentManager.shared
  var popup: Popup
  var history: History
  var footer: Footer

  var isPromptMode: Bool = true  // Default to prompt mode
  var promptText: String = ""
  var isSearchMode: Bool = false  // Track search mode separately
  private var preservedSelections: Set<UUID> = []
  
  // Prompt chips state
  var promptChips: [PromptChip] = [] {
    didSet {
      PromptChipsStore.save(promptChips)
      updateFooterItemVisibility()
      popup.needsResize = true
    }
  }
  
  // Notification to request focusing the input field from subviews
  static let focusInputNotification = Notification.Name("nozzle.focusInput")
  
  // Preview pane state management
  var showPreviewPane: Bool = Defaults[.showPreviewPane] {
    didSet {
      Defaults[.showPreviewPane] = showPreviewPane
    }
  }
  
  var previewItem: HistoryItemDecorator? {
    return history.selectedItem
  }
  
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
    
    // Clear all selected items
    history.items.forEach { $0.isSelected = false }
    
    // Clear preserved selections
    preservedSelections.removeAll()
    
    // Clear prompt text
    promptText = ""
    
    // Clear search query
    history.searchQuery = ""
    
    
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
    // Phase 2: Use centralized selection from ContentManager
    let selectedContentItems = contentManager.selectedItems
    let hasPrompt = !promptText.isEmpty
    let hasSelectedItems = !selectedContentItems.isEmpty
    
    guard hasPrompt || hasSelectedItems else { return }
    
    // Store current selection states and prompt text
    let currentPromptText = promptText
    
    // Enable multi-paste mode to prevent clipboard monitoring (only for clipboard items)
    let hasClipboardItems = selectedContentItems.contains { $0.sourceType == .clipboard }
    if hasClipboardItems {
      Clipboard.shared.setMultiPasteMode(true)
    }
    
    // Close the popup immediately for better UX
    popup.close()
    
    // Separate text items from media items
    var textContentItems: [ContentItem] = []
    var mediaContentItems: [ContentItem] = []
    
    for item in selectedContentItems {
      if item.imageData != nil || (item.fileURL != nil && !item.isText) {
        // Treat items with images or non-text files as media
        mediaContentItems.append(item)
      } else {
        // Treat everything else as text (including text files)
        textContentItems.append(item)
      }
    }
    
    // Execute the paste operations
    executeCombinedPaste(
      textItems: textContentItems,
      mediaItems: mediaContentItems,
      promptText: currentPromptText,
      hasClipboardItems: hasClipboardItems
    )
  }
  
  @MainActor
  private func executeCombinedPaste(
    textItems: [ContentItem],
    mediaItems: [ContentItem],
    promptText: String,
    hasClipboardItems: Bool
  ) {
    // Step 1: Combine and paste all text content as one operation
    if !textItems.isEmpty || !promptText.isEmpty || !promptChips.isEmpty {
      let (rtf, html, plain) = combinedFormattedContent(from: textItems, promptText: promptText, chips: promptChips)
      Clipboard.shared.copyFormattedText(rtf: rtf, html: html, plain: plain)
      
      // Wait for clipboard update, then paste
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
        Clipboard.shared.paste()
        
        // Step 2: After text is pasted, paste media items sequentially
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          self.pasteMediaItems(mediaItems, index: 0, promptText: promptText, hasClipboardItems: hasClipboardItems)
        }
      }
    } else {
      // No text content, just paste media items
      pasteMediaItems(mediaItems, index: 0, promptText: promptText, hasClipboardItems: hasClipboardItems)
    }
  }
  
  @MainActor
  private func pasteMediaItems(_ mediaItems: [ContentItem], index: Int, promptText: String, hasClipboardItems: Bool) {
    guard index < mediaItems.count else {
      // All operations complete, restore state
      finalizeCombinedPaste(promptText: promptText, hasClipboardItems: hasClipboardItems)
      return
    }
    
    let item = mediaItems[index]
    // Copy content item to clipboard
    if let imageData = item.imageData, let image = NSImage(data: imageData) {
      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      pasteboard.writeObjects([image])
    } else if let fileURL = item.fileURL {
      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      pasteboard.writeObjects([fileURL as NSURL])
    }
    
    // Wait for clipboard update, then paste
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
      Clipboard.shared.paste()
      
      // Wait before next media item
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        self.pasteMediaItems(mediaItems, index: index + 1, promptText: promptText, hasClipboardItems: hasClipboardItems)
      }
    }
  }
  
  @MainActor
  private func finalizeCombinedPaste(promptText: String, hasClipboardItems: Bool) {
    // Disable multi-paste mode (only if we had clipboard items)
    if hasClipboardItems {
      Clipboard.shared.setMultiPasteMode(false)
    }
    
    // Only call this in the App Store version.
    AppStoreReview.ask()
    
    // Restore selections after a short delay to ensure UI is updated
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      // Restore prompt text
      self.promptText = promptText
      
      // Phase 2: Selection is handled by ContentManager
      
      // Update footer visibility
      self.updateFooterItemVisibility()
    }
  }
  
  private func combinedFormattedContent(from items: [ContentItem], promptText: String, chips: [PromptChip]) -> (rtf: Data?, html: Data?, plain: String) {
    let combined = NSMutableAttributedString()
    
    // Add prompt as plain text if present
    if !promptText.isEmpty {
      combined.append(NSAttributedString(string: promptText + "\n"))
    }
    
    // Add chips content labeled <prompt i>
    if !chips.isEmpty {
      for (index, chip) in chips.enumerated() {
        let heading = "<prompt \(index + 1)>\n"
        combined.append(NSAttributedString(string: heading))
        let (rtfData, htmlData, plainText) = TextFileFormatter.loadAll(from: chip.url, type: UTType(filenameExtension: chip.url.pathExtension))
        if let rtfData = rtfData,
           let attributedString = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
          combined.append(attributedString)
        } else if let htmlData = htmlData,
                  let attributedString = NSAttributedString(html: htmlData, documentAttributes: nil) {
          combined.append(attributedString)
        } else if !plainText.isEmpty {
          combined.append(NSAttributedString(string: plainText))
        }
        combined.append(NSAttributedString(string: "\n"))
      }
    }
    
    // Add each item preserving its formatting
    for item in items {
      // Check if this is a file-backed text item that needs lazy loading
      if item.sourceType == .folder && item.isText && item.fileURL != nil {
        // Lazy load text file content
        let (rtfData, htmlData, plainText) = TextFileFormatter.loadAll(from: item.fileURL!, type: item.fileUTType)
        
        if let rtfData = rtfData,
           let attributedString = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
          combined.append(attributedString)
        } else if let htmlData = htmlData,
                  let attributedString = NSAttributedString(html: htmlData, documentAttributes: nil) {
          combined.append(attributedString)
        } else if !plainText.isEmpty {
          combined.append(NSAttributedString(string: plainText))
        }
      } else {
        // Use existing content for clipboard items
        if let rtfData = item.rtfData,
           let attributedString = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
          combined.append(attributedString)
        } else if let htmlData = item.htmlData,
                  let attributedString = NSAttributedString(html: htmlData, documentAttributes: nil) {
          combined.append(attributedString)
        } else if let text = item.plainText {
          combined.append(NSAttributedString(string: text))
        }
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
  
  // MARK: - Prompt chips helpers

  func addPromptChip(url: URL) {
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

}
