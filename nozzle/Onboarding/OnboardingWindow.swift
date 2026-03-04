import SwiftUI
import AppKit
import Defaults

@MainActor
class OnboardingWindow: NSWindowController {
    static var shared: OnboardingWindow?
    static let currentOnboardingVersion = 2

    static var needsOnboarding: Bool {
        !Defaults[.hasCompletedOnboarding] || Defaults[.onboardingVersion] < currentOnboardingVersion
    }

    static func markCompleted() {
        Defaults[.hasCompletedOnboarding] = true
        Defaults[.onboardingVersion] = currentOnboardingVersion
    }
    
    override init(window: NSWindow?) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 660),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        // Configure window appearance (Tahoe 26 style)
        // Hide title text next to traffic lights; keep a clean surface
        window.title = "Nozzle"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = false
        window.center()

        window.isOpaque = true
        // Solid, system-controlled background
        window.backgroundColor = .controlBackgroundColor
        window.hasShadow = true

        // Set content view
        let contentView = NSHostingView(rootView: OnboardingView())
        window.contentView = contentView

        super.init(window: window)

        window.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    static func showIfNeeded() {
        // Show for new users and users who have not seen the current onboarding version.
        guard needsOnboarding else { return }
        
        if shared == nil {
            shared = OnboardingWindow()
        }
        
        shared?.showWindow(nil)
        shared?.window?.makeKeyAndOrderFront(nil)
        
        // Bring app to front
        NSApp.activate(ignoringOtherApps: true)
        
        // Ensure window is frontmost when shown
        shared?.window?.level = .normal
    }
    
    static func show() {
        if shared == nil {
            shared = OnboardingWindow()
        }
        
        shared?.showWindow(nil)
        shared?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension OnboardingWindow: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return true
    }

    func windowWillClose(_ notification: Notification) {
        // Treat closing onboarding as dismissal for this version so it does not reopen every launch.
        if Self.needsOnboarding {
            Self.markCompleted()
        }
        OnboardingWindow.shared = nil
    }
}
