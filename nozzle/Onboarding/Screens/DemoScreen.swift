import SwiftUI

struct DemoScreen: View {
    @Environment(OnboardingState.self) private var onboardingState
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Demo Video header
                Text("Demo Video")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 16)
                
                // Video wireframe only (keep placeholder, remove extra copy)
                videoWireframe
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
    
    /// Wireframe placeholder for demo video
    @ViewBuilder
    private var videoWireframe: some View {
        RoundedRectangle(cornerRadius: 15)
            .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
            .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
            .frame(width: 480, height: 300)
            .overlay {
                VStack(spacing: 16) {
                    // Play button icon
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.4), lineWidth: 2)
                            .frame(width: 64, height: 64)
                        
                        Image(systemName: "play.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Demo Video")
                            .font(.system(.headline, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        Text("Video placeholder - will be replaced with actual demo")
                            .font(.system(.caption))
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }
            }
    }
}

#Preview {
    DemoScreen()
        .environment(OnboardingState())
        .frame(width: 800, height: 600)
}
