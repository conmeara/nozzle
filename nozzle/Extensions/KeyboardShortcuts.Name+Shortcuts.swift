import KeyboardShortcuts

extension KeyboardShortcuts.Name {
  static let popup = Self("popup", default: Shortcut(.v, modifiers: [.option]))
  static let pin = Self("pin", default: Shortcut(.p, modifiers: [.option]))
  static let delete = Self("delete", default: Shortcut(.delete, modifiers: [.option]))
  static let togglePreview = Self("togglePreview", default: Shortcut(.space, modifiers: [.option]))
  static let clearSelection = Self("clearSelection", default: Shortcut(.delete, modifiers: [.command]))
  static let togglePromptMode = Self("togglePromptMode", default: Shortcut(.f, modifiers: [.command]))
}
