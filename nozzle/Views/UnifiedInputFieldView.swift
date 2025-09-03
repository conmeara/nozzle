import SwiftUI

struct UnifiedInputFieldView: View {
  @Binding var query: String
  var isSearchMode: Bool = true
  @FocusState.Binding var isFocused: Bool

  @Environment(AppState.self) private var appState
  @Environment(ContentManager.self) private var contentManager
  
  // Removed inline mic button to avoid duplication with controls row
  
  private var placeholderText: String {
    if isSearchMode {
      return NSLocalizedString("search_placeholder", comment: "")
    } else {
      return NSLocalizedString("prompt_placeholder", comment: "")
    }
  }

  var body: some View {
    HStack(spacing: 6) {
      // Search icon only in search mode, inline with text
      if isSearchMode {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 11))
          .foregroundColor(.secondary)
          .opacity(0.8)
          .transition(.opacity.animation(.easeInOut(duration: 0.15)))
      }
      
      // Minimal transparent text field with multi-line support
      if isSearchMode {
        // Single-line TextField for search mode
        TextField(placeholderText, text: $query, axis: .horizontal)
          .textFieldStyle(.plain)
          .focused($isFocused)
          .disableAutocorrection(true)
          .lineLimit(1)
          .font(.system(size: 13))
          .onSubmit {
            handleSubmit()
          }
          .onChange(of: query) { oldValue, newValue in
            handleQueryChange(oldValue: oldValue, newValue: newValue)
          }
      } else {
        // Multi-line TextEditor for prompt mode with scrolling
        ZStack(alignment: .topLeading) {
          TextEditor(text: $query)
            .focused($isFocused)
            .disableAutocorrection(true)
            .font(.system(size: 13))
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .frame(minHeight: 20, maxHeight: 80) // ~4 lines max with scrolling
            .onChange(of: query) { oldValue, newValue in
              handleQueryChange(oldValue: oldValue, newValue: newValue)
            }
            .onSubmit {
              if !query.contains("\n") {
                handleSubmit()
              }
            }
          
          // Show placeholder when empty (TextEditor doesn't support placeholders)
          if query.isEmpty {
            Text(placeholderText)
              .font(.system(size: 13))
              .foregroundColor(.secondary.opacity(0.5))
              .padding(.horizontal, 5)
              .padding(.vertical, 8)
              .allowsHitTesting(false)
          }
        }
      }
      
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .animation(.easeInOut(duration: 0.15), value: isSearchMode)
  }
  
  @MainActor
  private func handleQueryChange(oldValue: String, newValue: String) {
    // If user types "/" at the beginning in any mode, jump to Prompts
    if oldValue.isEmpty && newValue == "/" {
      contentManager.activeSourceId = "prompts"
      // Set the search query to show slash commands
      if let src = contentManager.sources["prompts"] {
        src.searchQuery = newValue
      }
    }
  }
  
  @MainActor
  private func handleSubmit() {
    let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Handle Prompts source specially
    if contentManager.activeSourceId == "prompts" {
      // Slash commands
      if text == "/add" {
        let current = appState.promptText
        guard !current.isEmpty,
              let prompts = contentManager.sources["prompts"] as? PromptsSource else {
          return
        }
        // Use first line as a sensible filename
        let firstLine = current.split(whereSeparator: \.isNewline).first.map(String.init) ?? "Untitled"
        _ = prompts.createNewPrompt(named: firstLine, initialContents: current)
        query = "" // clear command
        return
      }
      
      if text == "/new" {
        if let prompts = contentManager.sources["prompts"] as? PromptsSource,
           let url = prompts.createNewPrompt() {
          // After refresh, focus the new item and open editor in preview
          Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            if let item = contentManager.activeItems.first(where: { $0.fileURL == url }) {
              contentManager.focus(item.id)
            }
          }
        }
        query = ""
        return
      }
      
      // No command: apply the first matching prompt
      if let first = contentManager.activeItems.first, 
         let url = first.fileURL,
         !(first.uniformTypeIdentifier?.hasPrefix("org.nozzle.command.") ?? false) {
        (contentManager.sources["prompts"] as? PromptsSource)?.applyPrompt(at: url)
        appState.addPromptChip(url: url)
        // Switch to prompt mode so the user can keep editing the input
        appState.isSearchMode = false
        appState.updateFooterItemVisibility()
        // Return to previous tab after choosing a prompt
        contentManager.activeSourceId = contentManager.lastNonPromptsSourceId
        // Keep the popup open; user can press ⏎ again to paste combined
      }
      return
    }
    
    // Default behavior for other sources
    appState.select()
  }
}


#Preview {
  @FocusState var focused: Bool
  
  return VStack(spacing: 20) {
    // Search mode
    UnifiedInputFieldView(
      query: .constant(""),
      isSearchMode: true,
      isFocused: $focused
    )
    
    // Prompt mode empty
    UnifiedInputFieldView(
      query: .constant(""),
      isSearchMode: false,
      isFocused: $focused
    )
    
    // Prompt mode with text
    UnifiedInputFieldView(
      query: .constant("This is a longer prompt that might wrap to multiple lines and can grow up to 10 lines with scrolling for even longer text"),
      isSearchMode: false,
      isFocused: $focused
    )
  }
  .frame(width: 400)
  .padding()
  .background(Color(NSColor.windowBackgroundColor))
  .environment(AppState.shared)
}
