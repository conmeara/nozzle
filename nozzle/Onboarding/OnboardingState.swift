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
    @ObservationIgnored nonisolated(unsafe) private var permissionTimer: Timer?

    enum Screen: Int, CaseIterable {
        case welcomeSetup = 0
        case shortcuts = 1
        case demo = 2
        case getStarted = 3

        var title: String {
            switch self {
            case .welcomeSetup:
                return OnboardingStrings.welcomeTitle
            case .shortcuts:
                return OnboardingStrings.shortcutsTitle
            case .demo:
                return OnboardingStrings.demoTitle
            case .getStarted:
                return OnboardingStrings.finishTitle
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
    var hasMicrophonePermission = false
    // Defaults are used before init syncs from current preferences.
    var launchAtLoginEnabled = false  // Requires explicit user consent per App Store guidelines
    var automaticUpdatesEnabled = true  // Initial value before sync
    
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
        // Sync initial toggle values from existing preferences.
        launchAtLoginEnabled = LaunchAtLogin.isEnabled
        automaticUpdatesEnabled = SoftwareUpdater.shared.automaticallyChecksForUpdates

        updatePermissionStatus()

        // Set up permission monitoring - check every second
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePermissionStatus()
            }
        }
    }
    
    deinit {
        permissionTimer?.invalidate()
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
        // Trigger the system prompt which auto-adds the app to the Accessibility list (toggled OFF).
        // This is better UX than just opening System Settings where the app isn't listed.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if trusted {
            hasAccessibilityPermission = true
        } else {
            // Also open System Settings so the user can toggle the switch ON
            Self.openAccessibilitySettings()
        }
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

        // Mark onboarding as completed for the current onboarding version.
        OnboardingWindow.markCompleted()
        
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
