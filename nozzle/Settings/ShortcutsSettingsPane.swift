import SwiftUI
import Defaults
import KeyboardShortcuts
import Settings

struct ShortcutsSettingsPane: View {
  @State private var copyModifier = ""
  @State private var pasteModifier = ""
  @State private var pasteWithoutFormatting = ""

  var body: some View {
    Settings.Container(contentWidth: 500) {
      Settings.Section(
        bottomDivider: true,
        label: { Text("Global Shortcuts", tableName: "ShortcutsSettings") }
      ) {
        VStack(alignment: .leading, spacing: 12) {
          HStack {
            Text("Open nozzle:", tableName: "ShortcutsSettings")
              .frame(width: 140, alignment: .leading)
            Spacer()
            KeyboardShortcuts.Recorder(for: .popup)
              .help(Text("OpenTooltip", tableName: "ShortcutsSettings"))
          }
          
          HStack {
            Text("Pin item:", tableName: "ShortcutsSettings")
              .frame(width: 140, alignment: .leading)
            Spacer()
            KeyboardShortcuts.Recorder(for: .pin)
              .help(Text("PinTooltip", tableName: "ShortcutsSettings"))
          }
          
          HStack {
            Text("Delete item:", tableName: "ShortcutsSettings")
              .frame(width: 140, alignment: .leading)
            Spacer()
            KeyboardShortcuts.Recorder(for: .delete)
              .help(Text("DeleteTooltip", tableName: "ShortcutsSettings"))
          }
          
          HStack {
            Text("Toggle preview:", tableName: "ShortcutsSettings")
              .frame(width: 140, alignment: .leading)
            Spacer()
            KeyboardShortcuts.Recorder(for: .togglePreview)
              .help(Text("TogglePreviewTooltip", tableName: "ShortcutsSettings"))
          }
          
          HStack {
            Text("Clear selection:", tableName: "ShortcutsSettings")
              .frame(width: 140, alignment: .leading)
            Spacer()
            KeyboardShortcuts.Recorder(for: .clearSelection)
              .help(Text("ClearSelectionTooltip", tableName: "ShortcutsSettings"))
          }
          
          HStack {
            Text("Toggle prompt mode:", tableName: "ShortcutsSettings")
              .frame(width: 140, alignment: .leading)
            Spacer()
            KeyboardShortcuts.Recorder(for: .togglePromptMode)
              .help(Text("TogglePromptModeTooltip", tableName: "ShortcutsSettings"))
          }
        }
      }

      Settings.Section(
        bottomDivider: true,
        label: { Text("Item Actions", tableName: "ShortcutsSettings") }
      ) {
        VStack(alignment: .leading, spacing: 12) {
          Text("Item action modifiers are determined by your paste behavior settings:", tableName: "ShortcutsSettings")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.bottom, 8)
          
          HStack {
            Text("Copy:", tableName: "ShortcutsSettings")
              .frame(width: 220, alignment: .leading)
            Spacer()
            Text(copyModifier)
              .font(.system(.body, design: .monospaced))
              .foregroundStyle(.primary)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Color.secondary.opacity(0.1))
              .cornerRadius(4)
          }
          
          HStack {
            Text("Paste:", tableName: "ShortcutsSettings")
              .frame(width: 220, alignment: .leading)
            Spacer()
            Text(pasteModifier)
              .font(.system(.body, design: .monospaced))
              .foregroundStyle(.primary)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Color.secondary.opacity(0.1))
              .cornerRadius(4)
          }
          
          HStack {
            Text("Paste without formatting:", tableName: "ShortcutsSettings")
              .frame(width: 220, alignment: .leading)
            Spacer()
            Text(pasteWithoutFormatting)
              .font(.system(.body, design: .monospaced))
              .foregroundStyle(.primary)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Color.secondary.opacity(0.1))
              .cornerRadius(4)
          }
        }
      }

      Settings.Section(
        label: { Text("Multi-Select & Navigation", tableName: "ShortcutsSettings") }
      ) {
        VStack(alignment: .leading, spacing: 8) {
          Group {
            HStack {
              Text("⏎")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
                .frame(width: 80, alignment: .center)
              Text("Toggle item selection", tableName: "ShortcutsSettings")
                .font(.caption)
              Spacer()
            }
            HStack {
              Text("⌘⏎")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
                .frame(width: 80, alignment: .center)
              Text("Paste combined content", tableName: "ShortcutsSettings")
                .font(.caption)
              Spacer()
            }
            HStack {
              Text("⌘⇧⏎")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
                .frame(width: 80, alignment: .center)
              Text("Paste single focused item", tableName: "ShortcutsSettings")
                .font(.caption)
              Spacer()
            }
            HStack {
              Text("⌘⌫")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
                .frame(width: 80, alignment: .center)
              Text("Clear selections and prompt", tableName: "ShortcutsSettings")
                .font(.caption)
              Spacer()
            }
            HStack {
              Text("⌘F")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
                .frame(width: 80, alignment: .center)
              Text("Toggle search/prompt mode", tableName: "ShortcutsSettings")
                .font(.caption)
              Spacer()
            }
          }
          
          Group {
            HStack {
              Text("⌘1-9")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
                .frame(width: 80, alignment: .center)
              Text("Toggle selection of numbered items", tableName: "ShortcutsSettings")
                .font(.caption)
              Spacer()
            }
            HStack {
              Text("⌘⇧1-9")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
                .frame(width: 80, alignment: .center)
              Text("Paste numbered item immediately", tableName: "ShortcutsSettings")
                .font(.caption)
              Spacer()
            }
            HStack {
              Text("⌥Space")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
                .frame(width: 80, alignment: .center)
              Text("Toggle preview", tableName: "ShortcutsSettings")
                .font(.caption)
              Spacer()
            }
            HStack {
              Text("↑↓")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
                .frame(width: 80, alignment: .center)
              Text("Navigate items", tableName: "ShortcutsSettings")
                .font(.caption)
              Spacer()
            }
            HStack {
              Text("Esc")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
                .frame(width: 80, alignment: .center)
              Text("Close popup", tableName: "ShortcutsSettings")
                .font(.caption)
              Spacer()
            }
          }
        }
        .foregroundStyle(.secondary)
      }
    }
    .onAppear {
      refreshModifiers()
    }
    .onChange(of: Defaults[.pasteByDefault]) { _ in
      refreshModifiers()
    }
    .onChange(of: Defaults[.removeFormattingByDefault]) { _ in
      refreshModifiers()
    }
  }

  private func refreshModifiers() {
    // Use fallback values since HistoryItemAction modifiers might not be available
    copyModifier = "⌘" // Command key for copy
    pasteModifier = "⌥" // Option key for paste (when paste by default is enabled)
    pasteWithoutFormatting = "⌥⌘" // Option+Command for paste without formatting
    
    // Try to get actual values, but keep fallbacks if they fail
    let copyFlags = HistoryItemAction.copy.modifierFlags
    let pasteFlags = HistoryItemAction.paste.modifierFlags
    let pasteWithoutFormattingFlags = HistoryItemAction.pasteWithoutFormatting.modifierFlags
    
    if !copyFlags.isEmpty {
      copyModifier = copyFlags.description
    }
    if !pasteFlags.isEmpty {
      pasteModifier = pasteFlags.description
    }
    if !pasteWithoutFormattingFlags.isEmpty {
      pasteWithoutFormatting = pasteWithoutFormattingFlags.description
    }
  }
}

#Preview {
  ShortcutsSettingsPane()
    .environment(\.locale, .init(identifier: "en"))
}