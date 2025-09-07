import AppKit

@MainActor
final class RenameEventCatcher {
    private var mouseMonitor: Any?
    private var keyMonitor: Any?
    private weak var window: NSWindow?
    private var armed = false

    /// Arm one-shot monitors when a rename starts
    func arm(in window: NSWindow) {
        guard !armed else { return }
        self.window = window
        armed = true

        // Return commits, Escape cancels
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] e in
            guard let self, self.armed else { return e }
            switch e.keyCode {
            case 36: // Return
                NotificationCenter.default.post(name: .CommitActiveRename, object: nil)
                return nil
            case 53: // Escape
                NotificationCenter.default.post(name: .CancelActiveRename, object: nil)
                return nil
            default:
                return e
            }
        }

        // First mouse click outside the inline TextField commits and is swallowed
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] e in
            guard let self, self.armed, let win = self.window else { return e }

            // Allow clicks inside the rename text field
            if self.clickIsInsideRenameField(event: e, window: win) {
                return e
            }

            // Commit and swallow the first click
            NotificationCenter.default.post(name: .CommitActiveRename, object: nil)
            self.disarm() // one-shot behavior
            return nil
        }
    }

    /// Disarm all monitors (call when rename completes/cancels)
    func disarm() {
        if let m = keyMonitor { NSEvent.removeMonitor(m) }
        if let m = mouseMonitor { NSEvent.removeMonitor(m) }
        keyMonitor = nil
        mouseMonitor = nil
        armed = false
    }

    // MARK: - Hit testing helper

    @MainActor
    private func clickIsInsideRenameField(event: NSEvent, window: NSWindow) -> Bool {
        guard let contentView = window.contentView else { return false }
        let p = contentView.convert(event.locationInWindow, from: nil)
        guard let hit = contentView.hitTest(p) else { return false }

        // Heuristic: SwiftUI TextField uses NSTextField; also allow clicks in the field editor
        var v: NSView? = hit
        while let current = v {
            if current is NSTextField || current is NSSearchField { return true }
            if let tv = window.firstResponder as? NSTextView,
               current === tv.enclosingScrollView || current === tv.superview { return true }
            v = current.superview
        }
        return false
    }
}
