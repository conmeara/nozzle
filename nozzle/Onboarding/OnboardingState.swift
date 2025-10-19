import SwiftUI
import Defaults
@preconcurrency import AppKit
import LaunchAtLogin
import ScreenCaptureKit

@Observable @MainActor
final class OnboardingState {
    enum Screen: Int, CaseIterable {
        case welcomeSetup = 0
        case shortcuts = 1
        case demo = 2
        case getStarted = 3
        
        var title: String {
            switch self {
            case .welcomeSetup:
                return "Welcome to Nozzle!"
            case .shortcuts:
                return "Guide"
            case .demo:
                return "Nozzle in Action"
            case .getStarted:
                return "Ready to go!"
            }
        }
        
        var description: String {
            switch self {
            case .welcomeSetup:
                return ""
            case .shortcuts:
                return ""
            case .demo:
                return ""
            case .getStarted:
                return ""
            }
        }
    }
    
    var currentScreen: Screen = .welcomeSetup
    var hasAccessibilityPermission = false
    var hasScreenRecordingPermission = false
    var launchAtLoginEnabled = true  // Default to ON
    
    // Computed properties
    var canContinue: Bool {
        switch currentScreen {
        case .welcomeSetup:
            return hasAccessibilityPermission // Require accessibility at minimum
        case .shortcuts:
            return true
        case .demo:
            return true
        case .getStarted:
            return false // No continue from finish
        }
    }
    
    var canGoBack: Bool {
        currentScreen.rawValue > 0
    }
    
    var progress: Double {
        Double(currentScreen.rawValue) / Double(Screen.allCases.count - 1)
    }
    
    init() {
        checkPermissions()
        
        // Set up permission monitoring
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPermissions()
            }
        }
    }
    
    nonisolated func checkPermissions() {
        Task { @MainActor in
            hasAccessibilityPermission = AXIsProcessTrustedWithOptions(nil)

            // Check screen recording permission for screenshot functionality
            if #available(macOS 12.3, *) {
                hasScreenRecordingPermission = await checkScreenRecordingPermission()
            }
        }
    }

    @available(macOS 12.3, *)
    private func checkScreenRecordingPermission() async -> Bool {
        // Try to get shareable content - this will fail if permission is denied
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            return true
        } catch {
            return false
        }
    }
    
    func requestAccessibilityPermission() {
        // Open System Settings to Accessibility privacy pane
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func requestScreenRecordingPermission() {
        // Open System Settings to Screen Recording privacy pane
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func nextScreen() {
        guard canContinue else { return }
        
        if currentScreen.rawValue < Screen.allCases.count - 1 {
            currentScreen = Screen(rawValue: currentScreen.rawValue + 1) ?? currentScreen
        }
    }
    
    func previousScreen() {
        guard canGoBack else { return }
        
        if currentScreen.rawValue > 0 {
            currentScreen = Screen(rawValue: currentScreen.rawValue - 1) ?? currentScreen
        }
    }
    
    func skipToFinish() {
        currentScreen = .getStarted
    }
    
    func completeOnboarding() {
        // Save launch at login preference
        // Note: This may fail in some environments (e.g., sandboxed or development builds)
        LaunchAtLogin.isEnabled = launchAtLoginEnabled
        
        // Mark onboarding as completed
        Defaults[.hasCompletedOnboarding] = true
        Defaults[.onboardingVersion] = 1
        
        // Close onboarding window
        OnboardingWindow.shared?.close()
        OnboardingWindow.shared = nil
        
        // Show menu bar tooltip after a short delay
        if let appDelegate = AppDelegate.shared {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                appDelegate.showMenuBarTooltip()
            }
        } else {
            // Try alternative method
            if let appDelegate = NSApp.delegate as? AppDelegate {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    appDelegate.showMenuBarTooltip()
                }
            }
        }
    }
}
