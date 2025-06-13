import AppKit
import Defaults
import Foundation
import Settings

@Observable
class AppState: Sendable {
  static let shared = AppState()

  var appDelegate: AppDelegate?
  var popup: Popup
  var history: History
  var footer: Footer

  var isPromptMode: Bool = true  // Default to prompt mode
  var promptText: String = ""
  var isSearchMode: Bool = false  // Track search mode separately
  
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

  private let about = About()
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
      // Show preview
      HistoryItemDecorator.previewThrottler.throttle {
        HistoryItemDecorator.previewThrottler.minimumDelay = 0.2
        item.showPreview = true
      }
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

  func openAbout() {
    about.openAbout(nil)
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
    // Find paste and copy footer items
    if let pasteItem = footer.items.first(where: { $0.title == "paste_combined" }),
       let copyItem = footer.items.first(where: { $0.title == "copy_combined" }) {
      // Show these items only if we have selected items or prompt text
      let hasContent = !history.selectedItems.isEmpty || !promptText.isEmpty
      pasteItem.isVisible = hasContent
      copyItem.isVisible = hasContent
    }
  }
  
  func clearSelectionAndPrompt() {
    // Clear all selected items
    history.items.forEach { $0.isSelected = false }
    
    // Clear prompt text
    promptText = ""
    
    // Clear search query
    history.searchQuery = ""
    
    // Update footer visibility
    updateFooterItemVisibility()
  }
  
  @MainActor
  func performCombinedPaste() {
    let selectedItems = history.selectedItems
    let hasPrompt = !promptText.isEmpty
    let hasSelectedItems = !selectedItems.isEmpty
    
    guard hasPrompt || hasSelectedItems else { return }
    
    // Close the popup immediately for better UX
    popup.close()
    
    // Build sequence of operations
    var operations: [(String, HistoryItem?)] = []
    
    // Add prompt if present
    if hasPrompt {
      operations.append(("prompt", nil))
    }
    
    // Add selected items
    for item in selectedItems {
      operations.append(("item", item.item))
    }
    
    // Execute operations sequentially with proper delays
    executeSequentialPaste(operations: operations, index: 0)
  }
  
  @MainActor
  private func executeSequentialPaste(operations: [(String, HistoryItem?)], index: Int) {
    guard index < operations.count else { return }
    
    let (type, item) = operations[index]
    
    // Perform the copy operation
    if type == "prompt" {
      Clipboard.shared.copyString(self.promptText)
    } else if let historyItem = item {
      Clipboard.shared.copy(historyItem)
    }
    
    // Wait for clipboard to update, then paste
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { // 50ms for clipboard update
      Clipboard.shared.paste()
      
      // Wait for paste to complete, then continue with next operation
      let nextDelay: TimeInterval = (type == "prompt") ? 0.1 : 0.15 // Extra time for complex data
      DispatchQueue.main.asyncAfter(deadline: .now() + nextDelay) {
        self.executeSequentialPaste(operations: operations, index: index + 1)
      }
    }
  }
  
  @MainActor
  func performCombinedCopy() {
    let combinedText = formatCombinedContent()
    guard !combinedText.isEmpty else { return }
    
    // Copy combined text to clipboard
    Clipboard.shared.copyString(combinedText)
    
    // Close the popup
    popup.close()
  }
  
  private func formatCombinedContent() -> String {
    // Get selected items
    let selectedItems = history.selectedItems
    
    // Check if we have content to combine
    guard !promptText.isEmpty || !selectedItems.isEmpty else { return "" }
    
    // Get the template from user defaults
    let template = Defaults[.pasteTemplate]
    
    // Get text content from selected items
    let itemTexts = selectedItems.map { $0.title }
    let itemsString = itemTexts.joined(separator: "\n")
    
    // Replace placeholders in template
    var output = template
      .replacingOccurrences(of: "{prompt}", with: promptText)
      .replacingOccurrences(of: "{items}", with: itemsString)
    
    // Clean up if prompt is empty
    if promptText.isEmpty {
      output = output.replacingOccurrences(of: "\nContext:\n", with: "")
    }
    
    return output.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
