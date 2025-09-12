import SwiftUI
import Defaults
import KeyboardShortcuts
import Settings

struct ShortcutsSettingsPane: View {
    @State private var shortcutsProvider = ShortcutsDataProvider.shared
    
    var body: some View {
        Settings.Container(contentWidth: 550) {
            Settings.Section(title: "") {
                VStack(spacing: 12) {
                    ForEach(customizableShortcuts, id: \.id) { shortcut in
                        shortcutRecorderRow(shortcut)
                    }
                }
            }
        }
    }
    
    /// Gets all customizable shortcuts across all categories
    private var customizableShortcuts: [ShortcutItem] {
        shortcutsProvider.categories.flatMap { category in
            category.shortcuts.filter { $0.isCustomizable }
        }
    }
    
    /// Row with KeyboardShortcuts.Recorder for customizable shortcuts
    @ViewBuilder
    private func shortcutRecorderRow(_ shortcut: ShortcutItem) -> some View {
        if let shortcutName = shortcut.shortcutName {
            HStack {
                Text(shortcut.description)
                    .frame(width: 180, alignment: .trailing)
                
                KeyboardShortcuts.Recorder(for: shortcutName)
                    .help(getTooltip(for: shortcut.description))
                    .onChange(of: KeyboardShortcuts.getShortcut(for: shortcutName)) { _, _ in
                        // Post notification to update other views
                        NotificationCenter.default.post(name: .shortcutDidChange, object: nil)
                    }
            }
        }
    }
    
    /// Gets tooltip text for a shortcut description
    private func getTooltip(for description: String) -> String {
        switch description {
        case "Open nozzle":
            return NSLocalizedString("OpenTooltip", tableName: "ShortcutsSettings", value: "Global shortcut to show the nozzle window", comment: "")
        case "Pin/Unpin item":
            return NSLocalizedString("PinTooltip", tableName: "ShortcutsSettings", value: "Pin or unpin the selected item", comment: "")
        case "Delete item":
            return NSLocalizedString("DeleteTooltip", tableName: "ShortcutsSettings", value: "Delete the selected item", comment: "")
        case "Toggle preview":
            return NSLocalizedString("TogglePreviewTooltip", tableName: "ShortcutsSettings", value: "Show or hide item preview", comment: "")
        case "Clear selection":
            return NSLocalizedString("ClearSelectionTooltip", tableName: "ShortcutsSettings", value: "Clear selected items and prompt text", comment: "")
        case "Toggle search/prompt":
            return NSLocalizedString("TogglePromptModeTooltip", tableName: "ShortcutsSettings", value: "Switch between search and prompt modes", comment: "")
        case "Toggle dictation":
            return NSLocalizedString("Toggle speech-to-text dictation", tableName: "ShortcutsSettings", value: "Toggle speech-to-text dictation", comment: "")
        case "Open prompts":
            return NSLocalizedString("Toggle prompts tab", tableName: "ShortcutsSettings", value: "Toggle prompts tab", comment: "")
        default:
            return description
        }
    }
}

#Preview {
  ShortcutsSettingsPane()
    .environment(\.locale, .init(identifier: "en"))
}