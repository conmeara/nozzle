import SwiftUI
import Defaults
import AppKit

struct OnboardingView: View {
    @State private var onboardingState = OnboardingState()
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Content area (header hidden on all pages)
                currentScreenView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .animation(.easeInOut(duration: 0.2), value: onboardingState.currentScreen)
            }

            // Floating next/finish button with Liquid Glass (accent blue)
            floatingNextButton
                .padding(20)
        }
        .ignoresSafeArea(edges: [.horizontal])
        .frame(minWidth: 680, minHeight: 520)
        .environment(onboardingState)
    }
    
    @ViewBuilder
    private var progressIndicator: some View {
        VStack(spacing: 6) {
            if !onboardingState.currentScreen.title.isEmpty {
                Text(onboardingState.currentScreen.title)
                    .font(.system(size: 22, weight: .bold))
            }
            if !onboardingState.currentScreen.description.isEmpty {
                Text(onboardingState.currentScreen.description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }
        }
        .padding(.bottom, 12)
    }
    
    @ViewBuilder
    private var currentScreenView: some View {
        switch onboardingState.currentScreen {
        case .welcomeSetup:
            WelcomeSetupScreen()
        case .shortcuts:
            ShortcutsScreen()
        case .demo:
            DemoVideoScreen()
        case .getStarted:
            GetStartedScreen()
        }
    }
    
    @ViewBuilder
    private var bottomUtilityRow: some View { EmptyView() }

    // Floating next/finish button styled with Liquid Glass
    @ViewBuilder
    private var floatingNextButton: some View {
        let isLast = onboardingState.currentScreen == .getStarted
        Button {
            if isLast {
                onboardingState.completeOnboarding()
            } else {
                onboardingState.nextScreen()
            }
        } label: {
            Image(systemName: isLast ? "checkmark" : "arrow.right")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 44, height: 44)
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.plain)
        .contentShape(Circle())
        .glassEffect(Glass.regular.tint(Color(NSColor.systemBlue)).interactive(), in: .circle)
        .foregroundStyle(Color.white)
        .opacity(onboardingState.canContinue || isLast ? 1.0 : 0.4)
        .disabled(!(onboardingState.canContinue || isLast))
        .help(isLast ? "Finish" : "Continue")
    }
}

#Preview {
    OnboardingView()
        .frame(width: 860, height: 620)
}
