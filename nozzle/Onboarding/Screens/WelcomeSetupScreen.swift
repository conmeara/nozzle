import SwiftUI
import AppKit
import LaunchAtLogin

struct WelcomeSetupScreen: View {
    @Environment(OnboardingState.self) private var onboardingState
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // App header
                welcomeHeader
                    .padding(.bottom, 12)  // Add extra padding after welcome
                // Permissions section
                permissionsSection
                
                // Launch at login section
                launchAtLoginSection
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
    
    @ViewBuilder
    private var welcomeHeader: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 15))

            Text("Welcome to Nozzle!")
                .font(.system(size: 22, weight: .bold))
        }
    }

    @ViewBuilder
    private var permissionsSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Permissions")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }
            
            VStack(spacing: 8) {
                // Accessibility Permission (simple row style to match Launch at Login)
                permissionRow(
                    icon: "accessibility",
                    title: "Accessibility Access",
                    description: "Required for clipboard monitoring and keyboard shortcuts",
                    isGranted: onboardingState.hasAccessibilityPermission
                ) {
                    onboardingState.requestAccessibilityPermission()
                }
            }
        }
    }
    
    @ViewBuilder
    private func permissionRow(
        icon: String,
        title: String,
        description: String,
        isGranted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.secondary)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isGranted {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Granted")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.green)
                }
            } else {
                Button("Grant") { action() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 6)
    }
    
    @ViewBuilder
    private var launchAtLoginSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Launch Settings")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }
            
            // Launch at login toggle
            HStack(spacing: 16) {
                Image(systemName: "power")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Launch at Login")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text("Start Nozzle automatically when you log in")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { onboardingState.launchAtLoginEnabled },
                    set: { onboardingState.launchAtLoginEnabled = $0 }
                ))
                    .toggleStyle(SwitchToggleStyle(tint: Color(NSColor.controlAccentColor)))
            }
            .padding(.vertical, 6)
        }
    }
}

#Preview {
    WelcomeSetupScreen()
        .environment(OnboardingState())
        .frame(width: 800, height: 600)
}
