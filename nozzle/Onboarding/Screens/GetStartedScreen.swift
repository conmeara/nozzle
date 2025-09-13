import SwiftUI
import AppKit

struct GetStartedScreen: View {
    @Environment(OnboardingState.self) private var onboardingState
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    // Finish screen with success header and resource tiles
    
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Success header
                successSection

                // Screenshot wireframe
                screenshotWireframe
                    .padding(.vertical, 8)

                // Resources section
                resourcesTiles
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        // No menu bar animation; concise finish presentation
    }

    // Success header with green check and guidance text
    @ViewBuilder
    private var successSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 42))
                    .foregroundColor(.green)
            }
            Text("Ready to go!")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
            Text("You can access the app through the menu bar icon or by ⌥ + V.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    /// Wireframe placeholder for screenshot
    @ViewBuilder
    private var screenshotWireframe: some View {
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

    // Resources as tiles styled like Shortcuts
    @ViewBuilder
    private var resourcesTiles: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Resources")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }

            let columns = [GridItem(.adaptive(minimum: 200), spacing: 16, alignment: .top)]
            LazyVGrid(columns: columns, spacing: 16) {
                resourceTile(
                    icon: "brain.head.profile",
                    title: "OpenAI Prompt Engineering",
                    subtitle: "Effective prompting",
                    url: "https://platform.openai.com/docs/guides/prompt-engineering"
                )
                resourceTile(
                    icon: "sparkles",
                    title: "Anthropic Prompt Library",
                    subtitle: "Proven prompts",
                    url: "https://docs.anthropic.com/claude/prompt-library"
                )
            }
        }
    }

    @ViewBuilder
    private func resourceTile(icon: String, title: String, subtitle: String, url: String) -> some View {
        Button {
            if let link = URL(string: url) { NSWorkspace.shared.open(link) }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.clear)
                        .frame(width: 34, height: 34)
                        .glassEffect(.regular, in: .rect(cornerRadius: 15))
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(NSColor.controlAccentColor))
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
            .padding(14)
            .contentShape(RoundedRectangle(cornerRadius: 15))
        }
        .buttonStyle(.plain)
        .glassEffect(.regular, in: .rect(cornerRadius: 15))
    }
}

#Preview {
    GetStartedScreen()
        .environment(OnboardingState())
        .frame(width: 800, height: 600)
}
