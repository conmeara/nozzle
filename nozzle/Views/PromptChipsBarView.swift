import SwiftUI

struct PromptChipsBarView: View {
  @Environment(AppState.self) private var appState
  @Environment(ContentManager.self) private var contentManager

  var body: some View {
    VStack(spacing: 0) {
      FlowLayout(spacing: 6, lineSpacing: 6) {
        ForEach(appState.promptChips) { chip in
          PromptChipView(chip: chip,
                         isActive: chipIsActive(chip)) {
            handleRemove(chip: chip)
          }
            .onTapGesture {
              // First activate the chip so it's highlighted immediately
              appState.activePromptChipId = chip.id
              appState.showPreviewPane = true
              
              // Switch to Prompts source first
              contentManager.activeSourceId = "prompts"
              
              // Then focus the specific item after a small delay to ensure
              // the tab switch completes and doesn't override our focus
              Task { @MainActor in
                // Small delay to let the onChange handler run first
                try? await Task.sleep(for: .milliseconds(10))
                if let item = contentManager.getItems(for: "prompts").first(where: { $0.fileURL == chip.url }) {
                  contentManager.focus(item.id)
                }
              }
              
              appState.requestFocusInput()
            }
        }

      }
    }
    .padding(.horizontal, 8)
    // Add a touch of breathing room above when chips are present
    .padding(.top, appState.promptChips.isEmpty ? 0 : 2)
    .animation(.easeInOut(duration: 0.2), value: appState.promptChips.count)
    // Clear active chip if focused preview changes away from active chip or Prompts closes
    .onChange(of: contentManager.focusedItemId) { _, _ in
      guard let activeId = appState.activePromptChipId else { return }
      // If the focused item does not match the active chip's URL anymore, clear
      if let activeChip = appState.promptChips.first(where: { $0.id == activeId }),
         contentManager.focusedContentItem?.fileURL != activeChip.url {
        appState.activePromptChipId = nil
      }
    }
    .onChange(of: contentManager.activeSourceId) { _, newValue in
      if newValue != "prompts" { appState.activePromptChipId = nil }
    }
  }

  // Helper to determine if a chip should be active (blue)
  private func chipIsActive(_ chip: PromptChip) -> Bool {
    // Activate if explicitly clicked
    if appState.activePromptChipId == chip.id {
      return true
    }
    
    // Also activate if we're on prompts tab and this chip's URL matches the focused item
    if contentManager.activeSourceId == "prompts",
       let focusedURL = contentManager.focusedContentItem?.fileURL,
       focusedURL == chip.url {
      return true
    }
    
    return false
  }

  private func handleRemove(chip: PromptChip) {
    let current = appState.promptChips
    guard let idx = current.firstIndex(of: chip) else {
      appState.removePromptChip(id: chip.id)
      return
    }
    let isActiveChip = isActive(chip)
    appState.removePromptChip(id: chip.id)
    if appState.activePromptChipId == chip.id { appState.activePromptChipId = nil }
    if isActiveChip {
      // Move focus to the next chip if available, else previous
      let newChips = appState.promptChips
      let nextIndex = min(idx, newChips.count - 1)
      if nextIndex >= 0, nextIndex < newChips.count {
        let next = newChips[nextIndex]
        contentManager.activeSourceId = "prompts"
        if let item = contentManager.getItems(for: "prompts").first(where: { $0.fileURL == next.url }) {
          contentManager.focus(item.id)
        }
        appState.activePromptChipId = next.id
      } else {
        // No chips left; clear preview focus
        contentManager.focus(nil)
      }
    }
  }
}

private struct PromptChipView: View {
  let chip: PromptChip
  let isActive: Bool
  let onRemove: () -> Void
  @Environment(AppState.self) private var appState

  @State private var hovering = false

  var body: some View {
    HStack(spacing: 6) {
      Text(chip.title)
        .font(.system(size: 12))
        .foregroundColor(isActive ? .primary : .secondary)
        .lineLimit(1)
      if hovering {
        Button(action: { onRemove() }) {
          Image(systemName: "xmark")
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary)
        }
        .buttonStyle(PlainButtonStyle())
      }
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(
      RoundedRectangle(cornerRadius: DesignConstants.cornerRadius)
        .fill(isActive ? Color(NSColor.controlAccentColor).opacity(0.20) : Color(NSColor.quaternaryLabelColor))
    )
    .onHover { hovering in
      self.hovering = hovering
    }
  }
}

// Keep chip highlight only when chip-driven preview is showing
extension PromptChipsBarView {
  // Helper mirrors previous signature for removal logic
  fileprivate func isActive(_ chip: PromptChip) -> Bool { chipIsActive(chip) }
}
