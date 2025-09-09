import SwiftUI
import AppKit
import Defaults

@MainActor
class OnboardingWindow: NSWindowController {
    static var shared: OnboardingWindow?
    
    override init(window: NSWindow?) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        // Configure window appearance (standard macOS look)
        window.title = "Welcome to nozzle"
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        window.isMovableByWindowBackground = false
        window.center()

        window.isOpaque = true
        window.backgroundColor = .windowBackgroundColor
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
        // Only show if onboarding hasn't been completed
        guard !Defaults[.hasCompletedOnboarding] else { return }
        
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
        // Allow closing but mark onboarding as completed
        Defaults[.hasCompletedOnboarding] = true
        Defaults[.onboardingVersion] = 1
        
        OnboardingWindow.shared = nil
        return true
    }
    
    func windowWillClose(_ notification: Notification) {
        OnboardingWindow.shared = nil
    }
}
