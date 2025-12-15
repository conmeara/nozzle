import SwiftUI

struct ShortcutsScreen: View {
    @Environment(OnboardingState.self) private var onboardingState
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var shortcutsProvider = ShortcutsDataProvider.shared
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                // App screenshot
                appScreenshotImage
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
    
    /// App screenshot image
    private var appScreenshotImage: some View {
        Image("onboarding-shortcuts")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    ShortcutsScreen()
        .environment(OnboardingState())
        .frame(width: 800, height: 600)
}
