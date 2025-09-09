import SwiftUI
import Defaults

struct OnboardingView: View {
    @State private var onboardingState = OnboardingState()
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    
    var body: some View {
        VStack(spacing: 0) {
            // Headings (per-screen)
            progressIndicator
                .padding(.top, 16)
                .padding(.horizontal, 24)

            // Content area
            currentScreenView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.2), value: onboardingState.currentScreen)

            // Navigation
            navigationButtons
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
        .frame(minWidth: 680, minHeight: 520)
        .environment(onboardingState)
    }
    
    @ViewBuilder
    private var progressIndicator: some View {
        VStack(spacing: 6) {
            Text(onboardingState.currentScreen.title)
                .font(.system(size: 22, weight: .bold))
            Text(onboardingState.currentScreen.description)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
        }
        .padding(.bottom, 12)
    }
    
    @ViewBuilder
    private var currentScreenView: some View {
        switch onboardingState.currentScreen {
        case .welcome:
            WelcomeScreen()
        case .permissions:
            PermissionsScreen()
        case .shortcuts:
            ShortcutsScreen()
        case .resources:
            ResourcesScreen()
        case .finish:
            FinishScreen()
        }
    }
    
    @ViewBuilder
    private var navigationButtons: some View {
        HStack {
            if onboardingState.canGoBack {
                Button("Back") { onboardingState.previousScreen() }
                    .keyboardShortcut(.cancelAction)
            } else {
                Button("Skip Setup") { onboardingState.skipToFinish() }
            }

            Spacer()

            if onboardingState.currentScreen == .finish {
                Button("Get Started") { onboardingState.completeOnboarding() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Continue") { onboardingState.nextScreen() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!onboardingState.canContinue)
            }
        }
    }
}

#Preview {
    OnboardingView()
        .frame(width: 860, height: 620)
}
