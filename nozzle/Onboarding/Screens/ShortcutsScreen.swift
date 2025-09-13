import SwiftUI

struct ShortcutsScreen: View {
    @Environment(OnboardingState.self) private var onboardingState
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var shortcutsProvider = ShortcutsDataProvider.shared
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                // Wireframe placeholder for app screenshot
                appScreenshotWireframe
                    .padding(.bottom, 8)
                
                ForEach(shortcutsProvider.categories) { category in
                    categorySection(category)
                }
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 14)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, alignment: .top)
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
        HStack(spacing: 16) {
            Text(shortcut.description)
                .font(.system(.body))
                .foregroundStyle(.primary)
                .frame(width: 200, alignment: .leading)
            
            ShortcutKeysView(keys: shortcut.keys)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }
    
    /// Wireframe placeholder for app screenshot
    @ViewBuilder
    private var appScreenshotWireframe: some View {
        RoundedRectangle(cornerRadius: 15)
            .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
            .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
            .frame(height: 200)
            .overlay {
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    
                    Text("App Screenshot")
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    Text("Screenshot placeholder - will be replaced with actual app image")
                        .font(.system(.caption))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
    }
}

#Preview {
    ShortcutsScreen()
        .environment(OnboardingState())
        .frame(width: 800, height: 600)
}
