import SwiftUI
import OSLog

class ApplicationImage: @unchecked Sendable {
  private static let logger = Logger(subsystem: "org.conmeara.nozzle", category: "ApplicationImage")
  fileprivate static let fallbackImage = NSImage(
    systemSymbolName: "questionmark.app.dashed",
    accessibilityDescription: nil
  )!
  private static let retryInterval: TimeInterval = 60 * 60

  let bundleIdentifier: String?
  private var image: NSImage?
  private var lastChecked: Date?
  private var eventSource: (any DispatchSourceFileSystemObject)?

  init(bundleIdentifier: String?, image: NSImage? = nil) {
    self.bundleIdentifier = bundleIdentifier
    self.image = image
  }

  var nsImage: NSImage {
    // If we have an image already, return it (for file type badges)
    if let image {
      return image
    }
    
    guard let bundleIdentifier else {
      return Self.fallbackImage
    }

    // The image has been queried before but since the application has been deleted.
    // Check from time to time if the application has returned.
    if let lastChecked,
      Date().timeIntervalSince(lastChecked) < Self.retryInterval {
      return Self.fallbackImage
    }
    lastChecked = .now

    if let appURL = NSWorkspace.shared.urlForApplication(
      withBundleIdentifier: bundleIdentifier
    ) {
      let img = NSWorkspace.shared.icon(forFile: appURL.path)
      image = img

      let descriptor = open(appURL.path, O_EVTONLY)
      if descriptor == -1 {
        let errorCode = errno
        Self.logger.warning("Failed to open file descriptor: errno=\(errorCode, privacy: .public) \(String(cString: strerror(errorCode)), privacy: .public)")
      } else if descriptor > 0 {
        let source = DispatchSource.makeFileSystemObjectSource(
          fileDescriptor: descriptor,
          eventMask: [.write, .delete],
          queue: DispatchQueue.global()
        )
        eventSource = source
        source.setEventHandler {
          DispatchQueue.main.async {
            let event = source.data
            if event.contains(.delete) {
              // File was deleted.
              Self.logger.debug("Application deleted: \(appURL.path, privacy: .public)")
              source.cancel()
              self.image = nil
            } else if event.contains(.write) {
              // File was modified. Fetch new icon
              Self.logger.debug("Application modified: \(appURL.path, privacy: .public)")
              self.image = NSWorkspace.shared.icon(forFile: appURL.path)
            }
          }
        }
        source.setCancelHandler {
          close(descriptor)
        }
        source.resume()
      }

      return img
    }

    return Self.fallbackImage
  }
}
