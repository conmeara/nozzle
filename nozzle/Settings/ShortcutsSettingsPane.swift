import SwiftUI
import Defaults
import KeyboardShortcuts
import Settings

struct ShortcutsSettingsPane: View {
  
  var body: some View {
    Settings.Container(contentWidth: 550) {
      Settings.Section(title: "", bottomDivider: true) {
        VStack(spacing: 12) {
          HStack {
            Text("Open nozzle:", tableName: "ShortcutsSettings")
              .frame(width: 160, alignment: .trailing)
            KeyboardShortcuts.Recorder(for: .popup)
              .help(Text("OpenTooltip", tableName: "ShortcutsSettings"))
          }
          
          HStack {
            Text("Pin item:", tableName: "ShortcutsSettings")
              .frame(width: 160, alignment: .trailing)
            KeyboardShortcuts.Recorder(for: .pin)
              .help(Text("PinTooltip", tableName: "ShortcutsSettings"))
          }
          
          HStack {
            Text("Delete item:", tableName: "ShortcutsSettings")
              .frame(width: 160, alignment: .trailing)
            KeyboardShortcuts.Recorder(for: .delete)
              .help(Text("DeleteTooltip", tableName: "ShortcutsSettings"))
          }
          
          HStack {
            Text("Toggle preview:", tableName: "ShortcutsSettings")
              .frame(width: 160, alignment: .trailing)
            KeyboardShortcuts.Recorder(for: .togglePreview)
              .help(Text("TogglePreviewTooltip", tableName: "ShortcutsSettings"))
          }
          
          HStack {
            Text("Clear selection:", tableName: "ShortcutsSettings")
              .frame(width: 160, alignment: .trailing)
            KeyboardShortcuts.Recorder(for: .clearSelection)
              .help(Text("ClearSelectionTooltip", tableName: "ShortcutsSettings"))
          }
          
          HStack {
            Text("Toggle prompt mode:", tableName: "ShortcutsSettings")
              .frame(width: 160, alignment: .trailing)
            KeyboardShortcuts.Recorder(for: .togglePromptMode)
              .help(Text("TogglePromptModeTooltip", tableName: "ShortcutsSettings"))
          }
        }
      }

      Settings.Section(title: "") {
        VStack(spacing: 12) {
          HStack {
            Text("Toggle selection:", tableName: "ShortcutsSettings")
              .frame(width: 160, alignment: .trailing)
            Text("⏎")
              .font(.system(.body, design: .monospaced))
              .foregroundStyle(.primary)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Color.secondary.opacity(0.1))
              .cornerRadius(4)
          }
          
          HStack {
            Text("Paste combined:", tableName: "ShortcutsSettings")
              .frame(width: 160, alignment: .trailing)
            Text("⌘⏎")
              .font(.system(.body, design: .monospaced))
              .foregroundStyle(.primary)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Color.secondary.opacity(0.1))
              .cornerRadius(4)
          }
          
          HStack {
            Text("Paste single item:", tableName: "ShortcutsSettings")
              .frame(width: 160, alignment: .trailing)
            Text("⌘⇧⏎")
              .font(.system(.body, design: .monospaced))
              .foregroundStyle(.primary)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Color.secondary.opacity(0.1))
              .cornerRadius(4)
          }
          
          HStack {
            Text("Clear selection:", tableName: "ShortcutsSettings")
              .frame(width: 160, alignment: .trailing)
            Text("⌘⌫")
              .font(.system(.body, design: .monospaced))
              .foregroundStyle(.primary)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Color.secondary.opacity(0.1))
              .cornerRadius(4)
          }
          
          HStack {
            Text("Toggle mode:", tableName: "ShortcutsSettings")
              .frame(width: 160, alignment: .trailing)
            Text("⌘F")
              .font(.system(.body, design: .monospaced))
              .foregroundStyle(.primary)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Color.secondary.opacity(0.1))
              .cornerRadius(4)
          }
          
          HStack {
            Text("Toggle numbered:", tableName: "ShortcutsSettings")
              .frame(width: 160, alignment: .trailing)
            Text("⌘1-9")
              .font(.system(.body, design: .monospaced))
              .foregroundStyle(.primary)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Color.secondary.opacity(0.1))
              .cornerRadius(4)
          }
          
          HStack {
            Text("Paste numbered:", tableName: "ShortcutsSettings")
              .frame(width: 160, alignment: .trailing)
            Text("⌘⇧1-9")
              .font(.system(.body, design: .monospaced))
              .foregroundStyle(.primary)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Color.secondary.opacity(0.1))
              .cornerRadius(4)
          }
          
          HStack {
            Text("Toggle preview:", tableName: "ShortcutsSettings")
              .frame(width: 160, alignment: .trailing)
            Text("⌥Space")
              .font(.system(.body, design: .monospaced))
              .foregroundStyle(.primary)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Color.secondary.opacity(0.1))
              .cornerRadius(4)
          }
          
          HStack {
            Text("Navigate:", tableName: "ShortcutsSettings")
              .frame(width: 160, alignment: .trailing)
            Text("↑↓")
              .font(.system(.body, design: .monospaced))
              .foregroundStyle(.primary)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Color.secondary.opacity(0.1))
              .cornerRadius(4)
          }
          
          HStack {
            Text("Close popup:", tableName: "ShortcutsSettings")
              .frame(width: 160, alignment: .trailing)
            Text("Esc")
              .font(.system(.body, design: .monospaced))
              .foregroundStyle(.primary)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Color.secondary.opacity(0.1))
              .cornerRadius(4)
          }
        }
      }
    }
  }
}

#Preview {
  ShortcutsSettingsPane()
    .environment(\.locale, .init(identifier: "en"))
}