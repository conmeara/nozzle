import SwiftUI
import AppKit

struct ResourcesScreen: View {
    @Environment(OnboardingState.self) private var onboardingState
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    
    var body: some View {
        VStack(spacing: 12) {
            promptEngineeringSection
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var introSection: some View { EmptyView() }
    
    @ViewBuilder
    private var promptEngineeringSection: some View {
        VStack(spacing: 10) {
            HStack { Text("Prompt Engineering").font(.system(size: 16, weight: .semibold)); Spacer() }
            VStack(spacing: 8) {
                resourceRow(
                    icon: "brain.head.profile",
                    title: "OpenAI Prompt Engineering",
                    subtitle: "Guide to effective prompting",
                    url: "https://platform.openai.com/docs/guides/prompt-engineering"
                )
                resourceRow(
                    icon: "sparkles",
                    title: "Anthropic Prompt Library",
                    subtitle: "Proven prompts for many tasks",
                    url: "https://docs.anthropic.com/claude/prompt-library"
                )
            }
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var documentationSection: some View { EmptyView() }
    
    @ViewBuilder
    private var communitySection: some View { EmptyView() }
    
    @ViewBuilder
    private func resourceRow(icon: String, title: String, subtitle: String, url: String) -> some View {
        Button {
            if let link = URL(string: url) { NSWorkspace.shared.open(link) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(Color(NSColor.controlAccentColor))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .medium))
                    Text(subtitle).font(.system(size: 12)).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right").foregroundColor(.secondary)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func documentationRow(
        icon: String,
        title: String,
        description: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Actions
    // Additional helpers removed for a minimal resources list
}


#Preview {
    ResourcesScreen()
        .environment(OnboardingState())
        .frame(width: 800, height: 600)
}
