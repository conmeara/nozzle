import SwiftUI

/// Main keyboard shortcuts panel view with liquid glass styling
struct ShortcutsPanelView: View {
    @Binding var isShowing: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            header
            
            // Scrollable content
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(ShortcutData.categories) { category in
                        categorySection(category)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
        }
        .modifier(LiquidGlassModifier(reduceTransparency: reduceTransparency))
        .onKeyPress(keys: ["/"]) { keyPress in
            // Handle Cmd+/ to close panel
            if keyPress.modifiers == .command {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isShowing = false
                }
                return .handled
            }
            return .ignored
        }
        .onKeyPress(keys: [KeyEquivalent.escape]) { _ in
            // Handle Escape to close panel
            withAnimation(.easeInOut(duration: 0.2)) {
                isShowing = false
            }
            return .handled
        }
    }
    
    /// Header with title and close hint
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Icon and title
                HStack(spacing: 8) {
                    Image(systemName: "command")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary)
                    
                    Text("Keyboard Shortcuts")
                        .font(.system(.title2, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                // Close hint
                HStack(spacing: 4) {
                    Text("Press")
                        .font(.system(.caption))
                        .foregroundStyle(.secondary)
                    
                    ShortcutKeyView(keyComponent: .modifier("⌘"))
                        .scaleEffect(0.8)
                    
                    Text("+")
                        .font(.system(.caption))
                        .foregroundStyle(.secondary.opacity(0.7))
                    
                    ShortcutKeyView(keyComponent: .key("/"))
                        .scaleEffect(0.8)
                    
                    Text("again or")
                        .font(.system(.caption))
                        .foregroundStyle(.secondary)
                    
                    ShortcutKeyView(keyComponent: .special("Esc"))
                        .scaleEffect(0.8)
                    
                    Text("to close")
                        .font(.system(.caption))
                        .foregroundStyle(.secondary)
                }
            }
            
            // Divider
            Rectangle()
                .fill(.secondary.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    /// Individual category section
    @ViewBuilder
    private func categorySection(_ category: ShortcutCategory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category title
            Text(category.title)
                .font(.system(.headline, weight: .medium))
                .foregroundStyle(.primary)
                .padding(.bottom, 4)
            
            // Shortcuts in category
            VStack(alignment: .leading, spacing: 8) {
                ForEach(category.shortcuts) { shortcut in
                    shortcutRow(shortcut)
                }
            }
        }
    }
    
    /// Individual shortcut row
    private func shortcutRow(_ shortcut: ShortcutItem) -> some View {
        HStack {
            Text(shortcut.description)
                .font(.system(.body))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
                .frame(minWidth: 20)
            
            ShortcutKeysView(keys: shortcut.keys)
        }
        .padding(.vertical, 2)
    }
}

#Preview("Light Mode") {
    ShortcutsPanelView(isShowing: .constant(true))
        .frame(width: 500, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .environment(\.colorScheme, .light)
}

#Preview("Dark Mode") {
    ShortcutsPanelView(isShowing: .constant(true))
        .frame(width: 500, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .environment(\.colorScheme, .dark)
}