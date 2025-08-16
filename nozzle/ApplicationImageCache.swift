actor ApplicationImageCache {
  static let shared = ApplicationImageCache()

  private let universalClipboardIdentifier: String =
  "com.apple.finder.Open-iCloudDrive"
  private let fallback = ApplicationImage(bundleIdentifier: nil)
  private var cache: [String: ApplicationImage] = [:]

  func getImage(universalClipboard: Bool, application: String?) -> ApplicationImage {
    guard let bundleIdentifier = bundleIdentifier(universalClipboard: universalClipboard, application: application) else {
      return fallback
    }

    if let image = cache[bundleIdentifier] {
      return image
    }

    let image = ApplicationImage(bundleIdentifier: bundleIdentifier)
    cache[bundleIdentifier] = image

    return image
  }

  private func bundleIdentifier(universalClipboard: Bool, application: String?) -> String? {
    if universalClipboard {
      return universalClipboardIdentifier
    }

    if let bundleIdentifier = application {
      return bundleIdentifier
    }

    return nil
  }
}
