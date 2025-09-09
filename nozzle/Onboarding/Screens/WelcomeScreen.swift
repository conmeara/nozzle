import SwiftUI
import AVKit

struct WelcomeScreen: View {
    @Environment(OnboardingState.self) private var onboardingState
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    
    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 20))

            Text("Let’s do a quick setup to tailor nozzle to your needs.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 6) {
                Image(systemName: "lightbulb")
                    .foregroundColor(.secondary)
                Text("Tip: Press ⌥V to open nozzle anywhere")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 6)

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var heroSection: some View { EmptyView() }
    
    @ViewBuilder
    private var screenshotPlaceholder: some View { EmptyView() }
    
    @ViewBuilder
    private var featureShowcase: some View { EmptyView() }
    
    @ViewBuilder
    private func videoPlaceholder(title: String, description: String, icon: String) -> some View { EmptyView() }
    
    @ViewBuilder
    private var valueProposition: some View { EmptyView() }
}

#Preview {
    WelcomeScreen()
        .environment(OnboardingState())
        .frame(width: 800, height: 600)
}
