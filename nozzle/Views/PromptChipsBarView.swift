import SwiftUI

struct PromptChipsBarView: View {
  @Environment(AppState.self) private var appState
  @Environment(ContentManager.self) private var contentManager

  var body: some View {
    VStack(spacing: 0) {
      FlowLayout(spacing: 6, lineSpacing: 6) {
        ForEach(appState.promptChips) { chip in
          PromptChipView(chip: chip,
                         isActive: isActive(chip)) {
            handleRemove(chip: chip)
          }
            .onTapGesture {
              // Activate Prompts source and focus corresponding item for preview
              contentManager.activeSourceId = "prompts"
              if let item = contentManager.getItems(for: "prompts").first(where: { $0.fileURL == chip.url }) {
                contentManager.focus(item.id)
                appState.selectWithoutScrolling(item.id)
              }
              appState.showPreviewPane = true
              appState.requestFocusInput()
            }
        }

      }
    }
    .padding(.horizontal, 8)
    .animation(.easeInOut(duration: 0.2), value: appState.promptChips.count)
  }

  private func isActive(_ chip: PromptChip) -> Bool {
    if let focused = contentManager.focusedContentItem?.fileURL {
      return focused == chip.url
    }
    return false
  }

  // Removed plus button here; use the existing plus below the input

  private func handleRemove(chip: PromptChip) {
    let current = appState.promptChips
    guard let idx = current.firstIndex(of: chip) else {
      appState.removePromptChip(id: chip.id)
      return
    }
    let isActiveChip = isActive(chip)
    appState.removePromptChip(id: chip.id)
    if isActiveChip {
      // Move focus to the next chip if available, else previous
      let newChips = appState.promptChips
      let nextIndex = min(idx, newChips.count - 1)
      if nextIndex >= 0, nextIndex < newChips.count {
        let next = newChips[nextIndex]
        contentManager.activeSourceId = "prompts"
        if let item = contentManager.getItems(for: "prompts").first(where: { $0.fileURL == next.url }) {
          contentManager.focus(item.id)
          appState.selectWithoutScrolling(item.id)
        }
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
      Image(nsImage: chip.icon)
        .resizable()
        .frame(width: 16, height: 16)
        .clipShape(RoundedRectangle(cornerRadius: 3))
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
      RoundedRectangle(cornerRadius: 8)
        .fill(isActive ? Color(NSColor.controlAccentColor).opacity(0.20) : Color(NSColor.quaternaryLabelColor))
    )
    .onHover { hovering in
      self.hovering = hovering
    }
  }
}
