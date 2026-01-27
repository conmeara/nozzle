import SwiftUI
import CoreGraphics
import Defaults
@preconcurrency import AppKit
@preconcurrency import ApplicationServices
import LaunchAtLogin
import ScreenCaptureKit

@Observable @MainActor
final class OnboardingState {
    enum Screen: Int, CaseIterable {
        case welcomeSetup = 0
        case shortcuts = 1
        case getStarted = 2

        var title: String {
            switch self {
            case .welcomeSetup:
                return "Welcome to Nozzle!"
            case .shortcuts:
                return "Guide"
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
            case .getStarted:
                return ""
            }
        }
    }
    
    var currentScreen: Screen = .welcomeSetup
    var hasAccessibilityPermission = false
    var hasScreenRecordingPermission = false
    var launchAtLoginEnabled = false  // Default to OFF - requires explicit user consent per App Store guidelines
    
    // Computed properties
    var canContinue: Bool {
        switch currentScreen {
        case .welcomeSetup:
            // Don't block users - permissions are recommended but not required
            // Important for unsigned builds where permission detection may fail
            // due to code signature differences from App Store version
            return true
        case .shortcuts:
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
        updatePermissionStatus()

        // Set up permission monitoring - check every second
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updatePermissionStatus()
            }
        }
    }

    /// Update permission status - called on main thread
    private func updatePermissionStatus() {
        // Check accessibility permission (synchronous)
        let newAccessibility = AXIsProcessTrustedWithOptions(nil)
        if newAccessibility != hasAccessibilityPermission {
            hasAccessibilityPermission = newAccessibility
        }

        // Check screen recording permission (synchronous, doesn't trigger prompt)
        let newScreenRecording = CGPreflightScreenCaptureAccess()
        if newScreenRecording != hasScreenRecordingPermission {
            hasScreenRecordingPermission = newScreenRecording
        }
    }
    
    func requestAccessibilityPermission() {
        // Trigger the system accessibility permission prompt
        // This will show the macOS dialog asking user to grant permission
        Self.promptForAccessibilityPermission()
    }

    /// Prompt for accessibility permission using the system dialog.
    /// nonisolated to safely access the kAXTrustedCheckOptionPrompt global constant.
    nonisolated private static func promptForAccessibilityPermission() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func requestScreenRecordingPermission() {
        // Use CGRequestScreenCaptureAccess to trigger the system permission prompt
        // This shows a dialog with "Open System Settings" and "Deny" buttons
        // The user can grant permission from there
        ScreenshotSource.requestScreenRecordingPermission()
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
        // Version 2 = nozzle v3.x onboarding with multi-source architecture
        Defaults[.hasCompletedOnboarding] = true
        Defaults[.onboardingVersion] = 2
        
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
