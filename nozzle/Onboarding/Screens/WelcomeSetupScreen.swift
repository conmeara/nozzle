import SwiftUI
import AppKit
import LaunchAtLogin

struct WelcomeSetupScreen: View {
    @Environment(OnboardingState.self) private var onboardingState
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Welcome section
                welcomeSection
                
                // Permissions section
                permissionsSection
                
                // Launch at login section
                launchAtLoginSection
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
    
    @ViewBuilder
    private var welcomeSection: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 20))

            Text("Let's do a quick setup to tailor nozzle to your needs.")
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
        }
    }
    
    @ViewBuilder
    private var permissionsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Permissions")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }
            
            VStack(spacing: 12) {
                // Accessibility Permission
                permissionCard(
                    icon: "accessibility",
                    title: "Accessibility Access",
                    description: "Required for clipboard monitoring and keyboard shortcuts",
                    isGranted: onboardingState.hasAccessibilityPermission,
                    isRequired: true
                ) {
                    onboardingState.requestAccessibilityPermission()
                }
            }
        }
    }
    
    @ViewBuilder
    private func permissionCard(
        icon: String,
        title: String,
        description: String,
        isGranted: Bool,
        isRequired: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(isGranted ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(isGranted ? .green : .orange)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if isRequired {
                        Text("Required")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                }
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            // Status and Action
            VStack(spacing: 8) {
                // Status indicator
                HStack(spacing: 6) {
                    Image(systemName: isGranted ? "checkmark.circle.fill" : "clock.circle")
                        .font(.system(size: 13))
                        .foregroundColor(isGranted ? .green : .orange)
                    
                    Text(isGranted ? "Granted" : "Pending")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isGranted ? .green : .orange)
                }
                
                // Grant button
                if !isGranted {
                    Button("Grant") { action() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 6)
    }
    
    @ViewBuilder
    private var launchAtLoginSection: some View {
        VStack(spacing: 16) {
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
                    
                    Text("Start nozzle automatically when you log in")
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