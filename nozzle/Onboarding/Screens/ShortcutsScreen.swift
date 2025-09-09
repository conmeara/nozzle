import SwiftUI
import KeyboardShortcuts

struct ShortcutsScreen: View {
    @Environment(OnboardingState.self) private var onboardingState
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    
    var body: some View {
        VStack(spacing: 12) {
            essentialShortcutsSection
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var introSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "keyboard")
                .font(.system(size: 48))
                .foregroundColor(Color(NSColor.controlAccentColor))
            
            VStack(spacing: 8) {
                Text("Keyboard Shortcuts")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Customize your shortcuts for maximum productivity. These can be changed later in Settings.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }
        }
    }
    
    @ViewBuilder
    private var essentialShortcutsSection: some View {
        VStack(spacing: 10) {
            HStack { Text("Keyboard Shortcuts").font(.system(size: 16, weight: .semibold)); Spacer() }
            VStack(spacing: 8) {
                shortcutRow(
                    for: .popup,
                    title: "Open nozzle",
                    description: "Show the main window",
                    icon: "rectangle.3.group.bubble",
                    isEssential: true
                )
                shortcutRow(
                    for: .togglePromptMode,
                    title: "Toggle Prompt Mode",
                    description: "Switch between search and prompt modes",
                    icon: "text.cursor",
                    isEssential: true
                )
                shortcutRow(
                    for: .clearSelection,
                    title: "Clear Selection",
                    description: "Clear selected items and prompt text",
                    icon: "clear",
                    isEssential: true
                )
            }
        }
        .padding(.vertical, 4)
    }
    
    private var advancedShortcutsSection: some View { EmptyView() }
    
    @ViewBuilder
    private func shortcutRow(
        for shortcut: KeyboardShortcuts.Name,
        title: String,
        description: String,
        icon: String,
        isEssential: Bool
    ) -> some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(isEssential ? Color(NSColor.controlAccentColor).opacity(0.1) : Color.secondary.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(isEssential ? 
                                   Color(NSColor.controlAccentColor) : 
                                   .secondary)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    
                    if isEssential {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(NSColor.controlAccentColor))
                    }
                    
                    Spacer()
                }
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Shortcut recorder
            KeyboardShortcuts.Recorder(for: shortcut)
                .frame(minWidth: 110)
        }
        .padding(.vertical, 4)
    }
    
    private var resetSection: some View { EmptyView() }
    
    private func resetAllShortcuts() {
        KeyboardShortcuts.reset(.popup)
        KeyboardShortcuts.reset(.togglePromptMode)
        KeyboardShortcuts.reset(.clearSelection)
        KeyboardShortcuts.reset(.pin)
        KeyboardShortcuts.reset(.delete)
        KeyboardShortcuts.reset(.togglePreview)
    }
}

// (Reset button style removed; using standard controls)

#Preview {
    ShortcutsScreen()
        .environment(OnboardingState())
        .frame(width: 800, height: 600)
}
