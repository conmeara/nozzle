import Foundation
import AppIntents

struct Get: AppIntent, CustomIntentMigratedAppIntent {
  static let intentClassName = "GetIntent"

  static let title: LocalizedStringResource = "Get Item from Clipboard History"
  static let description = IntentDescription("""
  Gets an item from nozzle clipboard history.
  The returned item can be used to access its plain/rich/HTML text, image contents or file location.
  """)

  @Parameter(title: "Selected", default: true)
  var selected: Bool

  @Parameter(title: "Number", default: 1)
  var number: Int

  private let positionOffset = 1

  static var parameterSummary: some ParameterSummary {
    When(\.$selected, .equalTo, false) {
      Summary {
        \.$number
        \.$selected
      }
    } otherwise: {
      Summary {
        \.$selected
      }
    }
  }

  func perform() async throws -> some IntentResult & ReturnsValue<HistoryItemAppEntity> {
    // Extract all data from HistoryItem while on MainActor
    let itemData = await MainActor.run {
      var item: HistoryItem?
      if selected {
        item = AppState.shared.history.selectedItem?.item
      } else {
        let index = number - positionOffset
        let items = AppState.shared.history.items
        if items.count >= index {
          item = items[index].item
        }
      }
      
      guard let item else {
        return Optional<(text: String?, htmlData: Data?, fileURLs: [URL], imageData: Data?, rtfData: Data?)>.none
      }
      
      // Extract all data while on MainActor
      return (
        text: item.text,
        htmlData: item.htmlData,
        fileURLs: item.fileURLs,
        imageData: item.imageData,
        rtfData: item.rtfData
      )
    }
    
    guard let itemData else {
      throw AppIntentError.notFound
    }

    let intentItem = HistoryItemAppEntity()
    intentItem.text = itemData.text ?? ""

    if let html = itemData.htmlData {
      intentItem.html = String(data: html, encoding: .utf8)
    }

    if let fileURL = itemData.fileURLs.first {
      intentItem.file = fileURL
    }

    if let imageData = itemData.imageData {
      let file = URL.documentsDirectory.appending(path: "image.png")
      try imageData.write(to: file, options: [Data.WritingOptions.atomic, Data.WritingOptions.completeFileProtection])
      intentItem.image = file
    }

    if let rtf = itemData.rtfData {
      intentItem.richText = String(data: rtf, encoding: .utf8)
    }

    return .result(value: intentItem)
  }
}
