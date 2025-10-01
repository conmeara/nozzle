import SwiftUI
import Defaults

/// Bottom banner displaying contextual keyboard shortcuts (Raycast-style)
struct ShortcutsBar: View {
    @Environment(AppState.self) private var appState
    @Environment(ContentManager.self) private var contentManager
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var shortcutsProvider = ContextualShortcutsProvider.shared
    @Default(.showShortcutsBar) private var showShortcutsBar
    @State private var isHovering = false

    var body: some View {
        if showShortcutsBar {
            VStack(spacing: 0) {
                // Subtle divider
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)

                // Shortcuts bar content
                HStack(spacing: 0) {
                    // Left side: shortcuts
                    HStack(spacing: 12) {
                        ForEach(Array(shortcuts.prefix(4).enumerated()), id: \.element.id) { index, shortcut in
                            // Shortcut item
                            HStack(spacing: 6) {
                                ShortcutKeysView(keys: shortcut.keys)
                                    .scaleEffect(0.8)

                                Text(shortcut.description)
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }

                            // Pipe separator (except after last item)
                            if index < min(shortcuts.count, 4) - 1 {
                                Text("|")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary.opacity(0.4))
                            }
                        }
                    }
                    .padding(.leading, 16)

                    Spacer()

                    // Right side: chevron toggle (bigger)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showShortcutsBar = false
                        }
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .opacity(isHovering ? 0.9 : 0.5)
                            .frame(width: 28, height: 24)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Hide shortcuts bar")
                    .padding(.trailing, 12)
                    .onHover { hovering in
                        isHovering = hovering
                    }
                }
                .padding(.vertical, 6)
                .background(
                    reduceTransparency
                        ? Color(NSColor.windowBackgroundColor).opacity(0.98)
                        : Color.clear
                )
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            // When hidden, show nothing but provide overlay in parent
            EmptyView()
        }
    }

    /// Compute contextual shortcuts based on current state
    private var shortcuts: [ContextualShortcutsProvider.ContextualShortcut] {
        let hasSelection = !contentManager.selectedItems.isEmpty
        let hasInput = !appState.promptText.isEmpty
        let hasChips = !appState.promptChips.isEmpty

        return shortcutsProvider.getContextualShortcuts(
            isSearchMode: appState.isSearchMode,
            hasSelection: hasSelection,
            hasInput: hasInput,
            hasChips: hasChips,
            activeTab: contentManager.activeSourceId,
            selectionCount: contentManager.selectedItems.count
        )
    }
}

#Preview("Prompt Mode - No Selection") {
    VStack {
        Spacer()
        ShortcutsBar()
            .environment(AppState.shared)
            .environment(ContentManager.shared)
    }
    .frame(width: 600, height: 400)
    .background(Color(NSColor.windowBackgroundColor))
}

#Preview("Prompt Mode - With Selection") {
    VStack {
        Spacer()
        ShortcutsBar()
            .environment({
                let state = AppState.shared
                // Simulate having selections
                return state
            }())
            .environment(ContentManager.shared)
    }
    .frame(width: 600, height: 400)
    .background(Color(NSColor.windowBackgroundColor))
}