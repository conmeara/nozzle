import SwiftUI

/// A view that renders a single keyboard key with flat design styling
struct ShortcutKeyView: View {
    let keyComponent: KeyComponent
    
    var body: some View {
        Text(keyComponent.displayText)
            .font(.system(.body, design: .monospaced, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(Color(NSColor.controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    /// Dynamic padding based on key type
    private var horizontalPadding: CGFloat {
        switch keyComponent {
        case .modifier:
            return 8
        case .key(let text):
            return text.count > 1 ? 12 : 8
        case .special(let text):
            return text.count > 1 ? 10 : 8
        }
    }
    
    private var verticalPadding: CGFloat {
        4
    }
}

/// A view that renders a sequence of keyboard keys for a shortcut
struct ShortcutKeysView: View {
    let keys: [KeyComponent]
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(keys.indices, id: \.self) { index in
                ShortcutKeyView(keyComponent: keys[index])
                
                // Add + separator between keys (except after the last key)
                if index < keys.count - 1 {
                    Text("+")
                        .font(.system(.body, design: .default, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 2)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        // Single keys
        HStack(spacing: 8) {
            ShortcutKeyView(keyComponent: .modifier("⌘"))
            ShortcutKeyView(keyComponent: .key("F"))
            ShortcutKeyView(keyComponent: .special("⏎"))
        }
        
        // Key sequences
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Toggle search/prompt:")
                    .frame(width: 160, alignment: .trailing)
                ShortcutKeysView(keys: [.modifier("⌘"), .key("F")])
            }
            
            HStack {
                Text("Paste combined:")
                    .frame(width: 160, alignment: .trailing)
                ShortcutKeysView(keys: [.special("⏎")])
            }
            
            HStack {
                Text("Open nozzle:")
                    .frame(width: 160, alignment: .trailing)
                ShortcutKeysView(keys: [.modifier("⌥"), .key("V")])
            }
        }
    }
    .padding()
    .background(Color(NSColor.windowBackgroundColor))
}