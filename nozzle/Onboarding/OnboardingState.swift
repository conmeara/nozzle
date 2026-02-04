import SwiftUI
import CoreGraphics
import Defaults
@preconcurrency import AppKit
@preconcurrency import ApplicationServices
import AVFoundation
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
    var hasMicrophonePermission = false
    var launchAtLoginEnabled = false  // Default to OFF - requires explicit user consent per App Store guidelines
    var automaticUpdatesEnabled = true  // Default to ON - most users want automatic updates
    
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

        // Check microphone permission (synchronous)
        let newMicrophone = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        if newMicrophone != hasMicrophonePermission {
            hasMicrophonePermission = newMicrophone
        }
    }
    
    func requestAccessibilityPermission() {
        // Open System Settings directly to the Accessibility privacy pane
        // This is more reliable for Developer ID apps than the system prompt
        Self.openAccessibilitySettings()
    }

    /// Opens System Settings to the Accessibility privacy pane
    nonisolated private static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func requestScreenRecordingPermission() {
        // Open System Settings directly to the Screen Recording privacy pane
        // This is more reliable and consistent with other permissions
        // CGRequestScreenCaptureAccess just shows a prompt telling user to go to settings anyway
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    func requestMicrophonePermission() {
        // Request microphone access - will show system dialog or open settings
        Task {
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            if status == .notDetermined {
                // Request access - shows system prompt
                let granted = await AVCaptureDevice.requestAccess(for: .audio)
                await MainActor.run {
                    hasMicrophonePermission = granted
                }
            } else if status == .denied || status == .restricted {
                // Open System Settings to the Microphone privacy pane
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                    NSWorkspace.shared.open(url)
                }
            }
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
        // Only attempt to set launch at login if the app is properly installed
        // (not running from Xcode's DerivedData or other non-standard locations)
        #if !DEBUG
        LaunchAtLogin.isEnabled = launchAtLoginEnabled
        #else
        // In debug builds, only set if explicitly enabled to avoid noisy errors
        if launchAtLoginEnabled {
            LaunchAtLogin.isEnabled = true
        }
        #endif

        // Save automatic updates preference
        SoftwareUpdater.shared.automaticallyChecksForUpdates = automaticUpdatesEnabled

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
