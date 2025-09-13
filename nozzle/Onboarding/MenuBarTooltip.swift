import SwiftUI
import AppKit

@MainActor
class MenuBarTooltip: NSWindow {
    private var dismissTimer: Timer?
    private let tooltipView: TooltipContentView
    
    init() {
        // Create the tooltip content view
        self.tooltipView = TooltipContentView()
        
        // Calculate initial size
        let initialSize = CGSize(width: 280, height: 80)
        
        // Initialize window
        super.init(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // Configure window appearance
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .popUpMenu
        self.hasShadow = true
        self.isReleasedWhenClosed = false
        self.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
        self.animationBehavior = .utilityWindow
        
        // Set content view
        self.contentView = NSHostingView(rootView: tooltipView)
        
        // Make window ignore mouse events initially (so clicks pass through)
        self.ignoresMouseEvents = false
    }
    
    func show(near statusButton: NSStatusBarButton) {
        // Get the button's window and frame
        guard let buttonWindow = statusButton.window else { return }
        let buttonFrame = buttonWindow.convertToScreen(statusButton.frame)
        
        // Calculate tooltip position (centered below the button)
        let tooltipWidth = self.frame.width
        let tooltipHeight = self.frame.height
        
        // Position below the menu bar button with some offset
        let xPosition = buttonFrame.midX - (tooltipWidth / 2)
        let yPosition = buttonFrame.minY - tooltipHeight - 12 // 12px gap from menu bar
        
        self.setFrameOrigin(NSPoint(x: xPosition, y: yPosition))
        
        // Animate appearance
        self.alphaValue = 0
        self.orderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1.0
        }
        
        // Set up auto-dismiss timer (5 seconds)
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.dismiss()
            }
        }
        
        // Dismiss on any click
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor in
                self?.dismiss()
            }
            return event
        }
    }
    
    func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0.0
        }, completionHandler: {
            Task { @MainActor in
                self.orderOut(nil)
            }
        })
    }
}

// SwiftUI content view for the tooltip
struct TooltipContentView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Arrow pointing up
            Triangle()
                .fill(backgroundColor)
                .frame(width: 16, height: 10)
                .offset(y: 1) // Slight overlap to connect with body
            
            // Main content
            HStack(spacing: 12) {
                Image(systemName: "v.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nozzle is ready!")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        Label("⌥V", systemImage: "option")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Text("or click here to open")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundColor)
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
            )
        }
        .fixedSize()
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark 
            ? Color(NSColor.controlBackgroundColor)
            : Color(NSColor.controlBackgroundColor)
    }
    
    private var accentColor: Color {
        Color(NSColor.controlAccentColor)
    }
}

// Triangle shape for the arrow
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
