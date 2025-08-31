import Foundation
import AppKit

struct PromptChip: Identifiable, Hashable, Sendable {
  let id: UUID
  let url: URL
  var title: String

  init(id: UUID = UUID(), url: URL) {
    self.id = id
    self.url = url
    self.title = url.deletingPathExtension().lastPathComponent
  }

  var icon: NSImage {
    NSWorkspace.shared.icon(forFile: url.path)
  }
}
