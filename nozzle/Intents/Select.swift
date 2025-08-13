import AppIntents

struct Select: AppIntent, CustomIntentMigratedAppIntent {
  static let intentClassName = "SelectIntent"

  static let title: LocalizedStringResource = "Select Item in Clipboard History"
  static let description = IntentDescription("""
  Selects an item in nozzle clipboard history.
  Depending on nozzle settings, it might trigger pasting of the selected item.
  """)

  static var parameterSummary: some ParameterSummary {
    Summary("Select \(\.$number) Item in Clipboard History")
  }

  @Parameter(title: "Number", default: 1, requestValueDialog: "What is the number of the item?")
  var number: Int

  private let positionOffset = 1

  func perform() async throws -> some IntentResult & ReturnsValue<String> {
    let (item, title): (HistoryItemDecorator?, String) = await MainActor.run {
      let items = AppState.shared.history.items
      let index = number - positionOffset
      guard items.count >= index else {
        return (nil, "")
      }
      
      let item = items[index]
      return (item, item.title)
    }
    
    guard let item else {
      throw AppIntentError.notFound
    }
    
    await AppState.shared.history.select(item)

    return .result(value: title)
  }
}
