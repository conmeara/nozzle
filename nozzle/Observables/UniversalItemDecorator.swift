import AppKit
import Defaults
import Observation
import UniformTypeIdentifiers

@Observable @MainActor
final class UniversalItemDecorator: ListItemDecorator {
    let id: UUID
    var base: ContentItem  // Made mutable so it can be updated
    let sourceId: String
    
    // Cached thumbnail for performance
    private var _thumbnailImage: NSImage?
    
    // App icon for clipboard items
    private var _appIcon: ApplicationImage?
    
    // Static thumbnail size to match HistoryItemDecorator
    static var thumbnailImageSize: NSSize { 
        NSSize(width: 340, height: Defaults[.imageMaxHeight]) 
    }
    
    // Derived UI
    var title: String {
        // For Prompts, hide the file extension from display
        if base.sourceId == "prompts", let url = base.fileURL {
            return url.deletingPathExtension().lastPathComponent
        }
        // For clipboard items with file URLs, show just the filename
        if base.sourceType == .clipboard, let url = base.fileURL {
            return url.lastPathComponent
        }
        return base.title
    }
    var isSelected: Bool {
        ContentManager.shared.isSelected(effectively: base)
    }
    var isExample: Bool {
        ContentManager.shared.isExample(id)
    }
    var isVisible: Bool {
        didSet { base.isVisible = isVisible }
    }
    
    // Type badge for file items
    var typeBadgeImage: ApplicationImage? {
        guard let type = base.fileUTType else { return nil }
        let nsImage = FileTypeBadgeCache.shared.icon(for: type)
        return ApplicationImage(bundleIdentifier: nil, image: nsImage)
    }
    
    // App icon for clipboard items
    var clipboardAppIcon: ApplicationImage? {
        if _appIcon == nil, base.sourceType == .clipboard {
            // For universal clipboard items (iCloud), show the iCloud icon
            if base.universalClipboard {
                Task {
                    let appIcon = await ApplicationImageCache.shared.getImage(
                        universalClipboard: true,
                        application: nil
                    )
                    await MainActor.run { self._appIcon = appIcon }
                }
            } else {
                // Derive effective bundle identifier, with heuristics for common sources like CleanShot
                var effectiveBundleId = base.applicationBundleId
                if let nozzleId = Bundle.main.bundleIdentifier, effectiveBundleId == nozzleId,
                   let url = base.fileURL, let guess = ScreenshotSourceHeuristics.guessBundleId(for: url) {
                    effectiveBundleId = guess
                }
                if effectiveBundleId == nil, let url = base.fileURL,
                   let guess = ScreenshotSourceHeuristics.guessBundleId(for: url) {
                    effectiveBundleId = guess
                }

                if let bundleId = effectiveBundleId {
                    Task {
                        let appIcon = await ApplicationImageCache.shared.getImage(
                            universalClipboard: false,
                            application: bundleId
                        )
                        await MainActor.run { self._appIcon = appIcon }
                    }
                }
            }
        }
        return _appIcon
    }
    
    // Protocol conformance - ListItemDecorator
    var appIcon: ApplicationImage? {
        // Clipboard items
        if base.sourceType == .clipboard {
            // If this clipboard item represents an image file, prefer the source app icon
            // to match historical behavior and user expectations. Detect via UTType or filename extension.
            if let url = base.fileURL {
                let isImageByUTI = base.isImage
                let isImageByExt = UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
                if isImageByUTI || isImageByExt {
                    return clipboardAppIcon ?? typeBadgeImage
                }
            }
            // For non-image file URLs copied to clipboard, use the file type badge
            if base.fileURL != nil {
                return typeBadgeImage
            }
            // Plain clipboard items (text, rich text, image data)
            return clipboardAppIcon ?? typeBadgeImage
        }
        // Non-clipboard sources: show a type badge when available
        return typeBadgeImage
    }
    var image: NSImage? { 
        if _thumbnailImage == nil, 
           let imageData = base.imageData,
           let nsImage = NSImage(data: imageData) {
            // Cache the resized thumbnail on first access
            _thumbnailImage = nsImage.resized(to: UniversalItemDecorator.thumbnailImageSize)
        }
        return _thumbnailImage
    }
    var accessoryImage: NSImage? { nil }
    var attributedTitle: AttributedString? { nil }
    var shortcuts: [KeyShortcut] { [] } // No numbered shortcuts for file sources in Phase 1
    
    init(_ item: ContentItem) {
        self.id = item.id
        self.base = item
        self.sourceId = item.sourceId
        self.isVisible = item.isVisible
        
        // Initialize app icon for clipboard items
        if item.sourceType == .clipboard {
            if item.universalClipboard {
                Task {
                    let appIcon = await ApplicationImageCache.shared.getImage(
                        universalClipboard: true,
                        application: nil
                    )
                    await MainActor.run {
                        self._appIcon = appIcon
                    }
                }
            } else if let bundleId = item.applicationBundleId {
                Task {
                    let appIcon = await ApplicationImageCache.shared.getImage(
                        universalClipboard: false,
                        application: bundleId
                    )
                    await MainActor.run {
                        self._appIcon = appIcon
                    }
                }
            }
        }
    }
    
    // Update the base ContentItem with new data while preserving decorator state
    func updateBase(_ newItem: ContentItem) {
        // Only update if the item is actually different
        guard newItem.id == self.id else { return }
        
        // Clear cached thumbnail if the file has changed
        if base.fileURL != newItem.fileURL || base.timestamp != newItem.timestamp {
            _thumbnailImage = nil
        }
        
        // Clear cached app icon if the application changed
        if base.applicationBundleId != newItem.applicationBundleId {
            _appIcon = nil
        }
        
        // Update the base item
        base = newItem
        isVisible = newItem.isVisible
        
        // Re-initialize app icon for clipboard items if needed
        if newItem.sourceType == .clipboard, _appIcon == nil {
            if newItem.universalClipboard {
                Task {
                    let appIcon = await ApplicationImageCache.shared.getImage(
                        universalClipboard: true,
                        application: nil
                    )
                    await MainActor.run {
                        self._appIcon = appIcon
                    }
                }
            } else if let bundleId = newItem.applicationBundleId {
                Task {
                    let appIcon = await ApplicationImageCache.shared.getImage(
                        universalClipboard: false,
                        application: bundleId
                    )
                    await MainActor.run {
                        self._appIcon = appIcon
                    }
                }
            }
        }
    }
    
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    nonisolated static func == (lhs: UniversalItemDecorator, rhs: UniversalItemDecorator) -> Bool {
        lhs.id == rhs.id
    }
    
    // Cross-source common action
    func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        if let url = base.fileURL {
            // For files, write the URL to pasteboard
            pasteboard.writeObjects([url as NSURL])
        } else if base.rtfData != nil || base.htmlData != nil || base.plainText != nil {
            // For rich content, write all available formats
            if let rtfData = base.rtfData {
                pasteboard.setData(rtfData, forType: .rtf)
            }
            if let htmlData = base.htmlData {
                pasteboard.setData(htmlData, forType: .html)
            }
            if let plainText = base.plainText {
                pasteboard.setString(plainText, forType: .string)
            }
        } else if let imageData = base.imageData {
            // For images, write the image data
            if let image = NSImage(data: imageData) {
                pasteboard.writeObjects([image])
            }
        }
    }
}
