import AppKit.NSWorkspace
import Defaults
import Foundation
import Observation
import Sauce
import UniformTypeIdentifiers

@Observable @MainActor
class HistoryItemDecorator: ListItemDecorator {
  nonisolated static func == (lhs: HistoryItemDecorator, rhs: HistoryItemDecorator) -> Bool {
    return lhs.id == rhs.id
  }

  // MainActor-isolated throttler for preview behavior
  static var previewThrottler = Throttler(minimumDelay: Double(Defaults[.previewDelay]) / 1000)
  static var previewImageSize: NSSize { NSScreen.forPopup?.visibleFrame.size ?? NSSize(width: 2048, height: 1536) }
  static var thumbnailImageSize: NSSize { NSSize(width: 340, height: Defaults[.imageMaxHeight]) }
  
  static func showPreviewImmediately(for item: HistoryItemDecorator) {
    previewThrottler.cancel()
    item.showPreview = true
  }

  let id = UUID()

  @ObservationIgnored
  private var hasFinishedInitialization = false

  var title: String = "" {
    didSet {
      guard hasFinishedInitialization, oldValue != title else { return }
      History.shared.registerDecoratorMutation()
    }
  }
  var attributedTitle: AttributedString?

  var isVisible: Bool = true {
    didSet {
      guard hasFinishedInitialization, oldValue != isVisible else { return }
      History.shared.registerDecoratorMutation()
    }
  }
  var isSelected: Bool = false {
    didSet {
      guard hasFinishedInitialization, oldValue != isSelected else { return }
      History.shared.registerDecoratorMutation()
    }
  }
  // Note: We no longer tie isSelected to preview display
  // as isSelected now represents checkbox state, not focus state
  var shortcuts: [KeyShortcut] = []
  var showPreview: Bool = false

  var application: String? {
    if item.universalClipboard {
      return "iCloud"
    }

    guard let bundle = item.application,
      let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle)
    else {
      return nil
    }

    return url.deletingPathExtension().lastPathComponent
  }

  var previewImage: NSImage?
  var thumbnailImage: NSImage?
  var applicationImage: ApplicationImage

  // 10k characters seems to be more than enough on large displays
  var text: String { item.previewableText.shortened(to: 10_000) }

  var isPinned: Bool { item.pin != nil }
  var isUnpinned: Bool { item.pin == nil }
  
  // File URL detection and icon support
  var hasFileURL: Bool { !item.fileURLs.isEmpty }
  var fileIcon: NSImage? {
    guard let firstFileURL = item.fileURLs.first else { return nil }
    return FileTypeBadgeCache.shared.icon(forURL: firstFileURL)
  }
  // Heuristic: treat first file's extension as type; avoid touching the file system when possible
  private var fileIsImage: Bool {
    guard let first = item.fileURLs.first else { return false }
    if let type = UTType(filenameExtension: first.pathExtension) {
      return type.conforms(to: .image)
    }
    return false
  }
  
  // Protocol conformance
  var appIcon: ApplicationImage? {
    if let fileIcon = fileIcon {
      // For clipboard file URLs: if it is an image, prefer the source application icon
      // to restore expected behavior for screenshots and copied images.
      if fileIsImage {
        return applicationImage
      }
      // Non-image files: show file type badge for alignment and quick recognition
      return ApplicationImage(bundleIdentifier: nil, image: fileIcon)
    }
    return applicationImage
  }
  var image: NSImage? { thumbnailImage }
  var accessoryImage: NSImage? { 
    // Only show colored circle when there's no thumbnail and no file icon
    return thumbnailImage != nil || fileIcon != nil ? nil : ColorImage.from(title) 
  }
  
  func copyToClipboard() {
    // Copy the item directly to avoid triggering clipboard monitoring
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    
    // Copy the item's contents to clipboard
    let contents = item.contents
    for content in contents {
      guard content.type != NSPasteboard.PasteboardType.fileURL.rawValue else { continue }
      pasteboard.setData(content.value, forType: NSPasteboard.PasteboardType(content.type))
    }
    
    // Handle file URLs separately (same as Clipboard.copy logic)
    let fileURLItems: [NSPasteboardItem] = contents.compactMap { item in
      guard item.type == NSPasteboard.PasteboardType.fileURL.rawValue else { return nil }
      guard let value = item.value else { return nil }
      let pasteItem = NSPasteboardItem()
      pasteItem.setData(value, forType: NSPasteboard.PasteboardType(item.type))
      return pasteItem
    }
    pasteboard.writeObjects(fileURLItems)
    
    // Update clipboard sync and change count to prevent re-detection
    Clipboard.shared.changeCount = pasteboard.changeCount
    
    // Update item metadata
    item.lastCopiedAt = Date.now
    item.numberOfCopies += 1
  }

  nonisolated func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  private(set) var item: HistoryItem

  init(_ item: HistoryItem, shortcuts: [KeyShortcut] = []) {
    self.item = item
    self.shortcuts = shortcuts
    self.title = item.title
    self.applicationImage = ApplicationImage(bundleIdentifier: nil) // Default fallback

    synchronizeItemPin()
    synchronizeItemTitle()
    Task {
      // Extract HistoryItem properties on MainActor before passing to actor
      let (universalClipboard, application, fileURLs) = await MainActor.run {
        (item.universalClipboard, item.application, item.fileURLs)
      }
      // Heuristic override: if the only available hint is Nozzle or nil, infer from file path
      var effectiveApp = application
      if let nozzleId = Bundle.main.bundleIdentifier, effectiveApp == nozzleId, let url = fileURLs.first {
        effectiveApp = ScreenshotSourceHeuristics.guessBundleId(for: url) ?? effectiveApp
      }
      if effectiveApp == nil, let url = fileURLs.first {
        effectiveApp = ScreenshotSourceHeuristics.guessBundleId(for: url)
      }

      self.applicationImage = await ApplicationImageCache.shared.getImage(
        universalClipboard: universalClipboard,
        application: effectiveApp
      )
    }
    Task { @MainActor in
      sizeImages()
    }

    hasFinishedInitialization = true
  }

  @MainActor
  func sizeImages() {
    guard let image = item.image else {
      return
    }

    previewImage = image.resized(to: HistoryItemDecorator.previewImageSize)
    thumbnailImage = image.resized(to: HistoryItemDecorator.thumbnailImageSize)
  }

  func highlight(_ query: String, _ ranges: [Range<String.Index>]) {
    guard !query.isEmpty, !title.isEmpty else {
      attributedTitle = nil
      return
    }

    var attributedString = AttributedString(title.shortened(to: 500))
    for range in ranges {
      if let lowerBound = AttributedString.Index(range.lowerBound, within: attributedString),
         let upperBound = AttributedString.Index(range.upperBound, within: attributedString) {
        switch Defaults[.highlightMatch] {
        case .bold:
          attributedString[lowerBound..<upperBound].font = .bold(.body)()
        case .italic:
          attributedString[lowerBound..<upperBound].font = .italic(.body)()
        case .underline:
          attributedString[lowerBound..<upperBound].underlineStyle = .single
        default:
          attributedString[lowerBound..<upperBound].backgroundColor = .findHighlightColor
          attributedString[lowerBound..<upperBound].foregroundColor = .black
        }
      }
    }

    attributedTitle = attributedString
  }

  @MainActor
  func togglePin() {
    if item.pin != nil {
      item.pin = nil
    } else {
      let pin = HistoryItem.randomAvailablePin
      item.pin = pin
    }
  }

  private func synchronizeItemPin() {
    _ = withObservationTracking {
      item.pin
    } onChange: {
      DispatchQueue.main.async {
        if let pin = self.item.pin {
          self.shortcuts = KeyShortcut.create(character: pin)
        }
        self.synchronizeItemPin()
      }
    }
  }

  private func synchronizeItemTitle() {
    _ = withObservationTracking {
      item.title
    } onChange: {
      DispatchQueue.main.async {
        self.title = self.item.title
        self.synchronizeItemTitle()
      }
    }
  }
}
