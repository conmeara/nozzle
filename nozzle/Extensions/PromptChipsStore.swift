import Foundation
import Defaults

enum PromptChipsStore {
  static func load() -> [PromptChip] {
    let datas = Defaults[.promptChipsBookmarks]
    var chips: [PromptChip] = []
    for data in datas {
      var isStale = false
      if let url = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale),
         !isStale {
        _ = url.startAccessingSecurityScopedResource()
        chips.append(PromptChip(url: url))
      }
    }
    return chips
  }

  static func save(_ chips: [PromptChip]) {
    let datas: [Data] = chips.compactMap { chip in
      try? chip.url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
    }
    Defaults[.promptChipsBookmarks] = datas
  }
}

