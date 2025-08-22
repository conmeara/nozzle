import Foundation
import UniformTypeIdentifiers
import AppKit
import SwiftUI

@MainActor
final class AutoSaveController: ObservableObject {
    private let throttler: Throttler
    private let url: URL
    private let utType: UTType?
    
    // Save hooks
    @Binding var content: String           // current content binding
    var onSaved: () -> Void = {}           // update UI badge
    
    init(url: URL, utType: UTType?, content: Binding<String>) {
        self.url = url
        self.utType = utType
        self._content = content
        self.throttler = Throttler(minimumDelay: 0.6)
    }
    
    func schedule() {
        throttler.throttle { [weak self] in
            Task { await self?.saveNow() }
        }
    }
    
    func saveNow() async {
        let text = content  // Get current content from binding
        
        // Get the parent directory for security scope access
        let parentURL = url.deletingLastPathComponent()
        let isSecurityScoped = parentURL.startAccessingSecurityScopedResource()
        
        defer {
            if isSecurityScoped {
                parentURL.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            try TextFileFormatter.save(string: text, to: url, type: utType)
            await MainActor.run {
                onSaved()
                // Important: ensure main window never shows edited dot
                NSApp.keyWindow?.isDocumentEdited = false
            }
        } catch {
            // Optional: surface non-fatal error UI
            print("AutoSave failed: \(error)")
        }
    }
    
    func cancel() {
        throttler.cancel()
    }
}