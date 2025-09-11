import SwiftUI
import AppKit

struct GetStartedScreen: View {
    @Environment(OnboardingState.self) private var onboardingState
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var showMenuBarTip = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Success section
                successSection
                
                // Menu bar tip
                menuBarTipSection
                
                // Resources section
                resourcesSection
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .onAppear {
            // Animate the menu bar tip after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                    showMenuBarTip = true
                }
            }
        }
    }
    
    @ViewBuilder
    private var successSection: some View {
        VStack(spacing: 16) {
            // Success icon with animation
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 72, height: 72)
                    .scaleEffect(showMenuBarTip ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: showMenuBarTip)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 42))
                    .foregroundColor(.green)
                    .scaleEffect(showMenuBarTip ? 1.0 : 0.8)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showMenuBarTip)
            }
            
            VStack(spacing: 12) {
                Text("Ready to go!")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Access nozzle from the menu bar or press ⌥V.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    @ViewBuilder
    private var menuBarTipSection: some View {
        VStack(spacing: 12) {
            Text("Find nozzle in your menu bar")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            // Menu bar illustration
            menuBarIllustration
            
            // Instructions
            HStack(spacing: 16) {
                instructionBadge(
                    icon: "option",
                    text: "⌥V",
                    description: "Quick access"
                )
                
                Text("or")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                
                instructionBadge(
                    icon: "cursorarrow.click",
                    text: "Click",
                    description: "Menu bar icon"
                )
            }
        }
    }
    
    @ViewBuilder
    private var menuBarIllustration: some View {
        HStack(spacing: 8) {
            // Left side of menu bar
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 12, height: 12)
                Circle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 12, height: 12)
                Circle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 12, height: 12)
            }
            
            Spacer()
            
            // Center - app name
            Text("macOS")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Right side - where nozzle appears
            HStack(spacing: 6) {
                // Other menu bar items
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 16, height: 16)
                    .cornerRadius(2)
                
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 16, height: 16)
                    .cornerRadius(2)
                
                // nozzle icon (highlighted)
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(NSColor.controlAccentColor).opacity(0.2))
                        .frame(width: 24, height: 16)
                    
                    Image(systemName: "v.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(NSColor.controlAccentColor))
                }
                .scaleEffect(showMenuBarTip ? 1.2 : 1.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.5), value: showMenuBarTip)
                
                // Animated pointer
                if showMenuBarTip {
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(NSColor.controlAccentColor))
                        .offset(y: 16)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.06))
        )
        .frame(maxWidth: 400)
    }
    
    @ViewBuilder
    private func instructionBadge(icon: String, text: String, description: String) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(NSColor.controlAccentColor))
                
                Text(text)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.controlAccentColor).opacity(0.1))
            )
            
            Text(description)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private var resourcesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Resources")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }
            
            VStack(spacing: 12) {
                Text("Learn Prompt Engineering")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
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
        }
    }
    
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
}

#Preview {
    GetStartedScreen()
        .environment(OnboardingState())
        .frame(width: 800, height: 600)
}