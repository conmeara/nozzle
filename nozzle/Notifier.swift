import AppKit
@preconcurrency import UserNotifications

class Notifier {
  private static var center: UNUserNotificationCenter { UNUserNotificationCenter.current() }

  static func authorize() {
    center.requestAuthorization(options: [.alert, .sound]) { @Sendable _, error in
      if error != nil {
        NSLog("Failed to authorize notifications: \(String(describing: error))")
      }
    }
  }

  static func notify(body: String?, sound: NSSound?) {
    guard let body else { return }

    // Don't request authorization - only show notifications if already authorized
    center.getNotificationSettings { @Sendable settings in
      guard (settings.authorizationStatus == .authorized) ||
            (settings.authorizationStatus == .provisional) else { return }

      let content = UNMutableNotificationContent()
      if settings.alertSetting == .enabled {
        content.body = body
      }

      let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
      center.add(request) { @Sendable error in
        if error != nil {
          NSLog("Failed to deliver notification: \(String(describing: error))")
        } else {
          if settings.soundSetting == .enabled {
            DispatchQueue.main.async {
              sound?.play()
            }
          }
        }
      }
    }
  }
}
