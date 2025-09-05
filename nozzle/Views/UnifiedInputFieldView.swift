import SwiftUI

struct UnifiedInputFieldView: View {
  @Binding var query: String
  var isSearchMode: Bool = true
  @FocusState.Binding var isFocused: Bool

  @Environment(AppState.self) private var appState
  @Environment(ContentManager.self) private var contentManager
  
  // State for dynamic text height
  @State private var textHeight: CGFloat = 20  // Start with single line height
  @State private var fieldWidth: CGFloat = 400  // Default width estimate
  
  // Removed inline mic button to avoid duplication with controls row
  
  private var placeholderText: String {
    if isSearchMode {
      return NSLocalizedString("search_placeholder", comment: "")
    } else {
      return NSLocalizedString("prompt_placeholder", comment: "")
    }
  }
  
  private func calculateTextHeight(_ text: String, width: CGFloat) -> CGFloat {
    let lineHeight: CGFloat = 18  // Approximate height per line for 13pt font  
    let baseHeight: CGFloat = 20  // Minimum single line height
    
    if text.isEmpty {
      return baseHeight
    }
    
    // Split by newlines and calculate total lines including wrapped lines
    let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
    var totalLines = 0
    
    // Calculate chars per line based on actual width
    // Font size 13pt typically has character width of about 7-8 points
    // For proportional fonts, average is about 6-7 points
    // Subtracting padding and using conservative estimate
    let charWidth: CGFloat = 7.0  // Average character width for 13pt font
    let usableWidth = max(100, width - 40)  // Account for padding and minimum width
    let charsPerLine = Int(usableWidth / charWidth)
    
    for line in lines {
      if line.isEmpty {
        totalLines += 1
      } else {
        // Calculate how many visual lines this text line will take
        let visualLines = (line.count - 1) / charsPerLine + 1
        totalLines += visualLines
      }
    }
    
    let calculatedHeight = baseHeight + CGFloat(max(0, totalLines - 1)) * lineHeight
    return min(calculatedHeight, 80)  // Cap at max height (~4 lines)
  }

  var body: some View {
    HStack(spacing: 4) {
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
        // Single-line TextField for search mode with custom placeholder
        ZStack(alignment: .leading) {
          TextField("", text: $query, axis: .horizontal)
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
          
          // Show placeholder when empty (matching prompt mode styling)
          if query.isEmpty {
            Text(placeholderText)
              .font(.system(size: 13))
              .foregroundColor(.secondary.opacity(0.5))
              .padding(.leading, 1)
              .allowsHitTesting(false)
          }
        }
      } else {
        // Multi-line TextEditor for prompt mode with scrolling
        GeometryReader { geometry in
          ZStack(alignment: .topLeading) {
            TextEditor(text: $query)
              .focused($isFocused)
              .disableAutocorrection(true)
              .font(.system(size: 13))
              .scrollContentBackground(.hidden)
              .background(Color.clear)
              .frame(height: textHeight)  // Dynamic height based on content
              .onChange(of: query) { oldValue, newValue in
                textHeight = calculateTextHeight(newValue, width: geometry.size.width)
                handleQueryChange(oldValue: oldValue, newValue: newValue)
              }
              .onChange(of: geometry.size.width) { _, newWidth in
                fieldWidth = newWidth
                textHeight = calculateTextHeight(query, width: newWidth)
              }
              .onSubmit {
                if !query.contains("\n") {
                  handleSubmit()
                }
              }
              .onAppear {
                fieldWidth = geometry.size.width
                textHeight = calculateTextHeight(query, width: geometry.size.width)
              }
            
            // Show placeholder when empty (TextEditor doesn't support placeholders)
            if query.isEmpty {
              Text(placeholderText)
                .font(.system(size: 13))
                .foregroundColor(.secondary.opacity(0.5))
                .padding(.leading, 6)
                .padding(.top, 0)
                .allowsHitTesting(false)
            }
          }
        }
        .frame(height: textHeight)  // Apply height to GeometryReader
        .padding(.bottom, -4)  // Reduce bottom padding to match search mode
      }
      
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .animation(.easeInOut(duration: 0.15), value: isSearchMode)
    .animation(.easeInOut(duration: 0.1), value: textHeight)
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
