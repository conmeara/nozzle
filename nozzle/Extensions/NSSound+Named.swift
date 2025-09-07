import AppKit.NSSound

extension NSSound {
  static let knock = NSSound(
    contentsOf: Bundle.main.url(forResource: "Knock", withExtension: "caf")!, byReference: true)
  static let write = NSSound(
    contentsOf: Bundle.main.url(forResource: "Write", withExtension: "caf")!, byReference: true)
  
  // Dictation sounds - use macOS dictation sounds with fallbacks
  static var dictationBegin: NSSound? {
    // Try macOS dictation sound first
    if let url = URL(string: "file:///System/Library/PrivateFrameworks/AssistantServices.framework/Versions/A/Resources/dt-begin.caf"),
       let sound = NSSound(contentsOf: url, byReference: true) {
      return sound
    }
    // Fallback to system sound
    return NSSound(named: "Hero")
  }
  
  static var dictationConfirm: NSSound? {
    // Try macOS dictation sound first
    if let url = URL(string: "file:///System/Library/PrivateFrameworks/AssistantServices.framework/Versions/A/Resources/dt-confirm.caf"),
       let sound = NSSound(contentsOf: url, byReference: true) {
      return sound
    }
    // Fallback to system sound
    return NSSound(named: "Glass")
  }
  
  static var dictationCancel: NSSound? {
    // Try macOS dictation sound first
    if let url = URL(string: "file:///System/Library/PrivateFrameworks/AssistantServices.framework/Versions/A/Resources/dt-cancel.caf"),
       let sound = NSSound(contentsOf: url, byReference: true) {
      return sound
    }
    // Fallback to system sound
    return NSSound(named: "Funk")
  }
}
