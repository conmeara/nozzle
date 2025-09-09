import SwiftUI
import AppKit

struct FinishScreen: View {
    @Environment(OnboardingState.self) private var onboardingState
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var showMenuBarTip = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Success section
            successSection
            
            // Menu bar tip
            menuBarTipSection
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    
    private var quickTipsSection: some View { EmptyView() }
    
    @ViewBuilder
    private func tipRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(NSColor.controlAccentColor))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    FinishScreen()
        .environment(OnboardingState())
        .frame(width: 800, height: 600)
}
