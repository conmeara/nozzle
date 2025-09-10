import SwiftUI
import AppKit

struct UnifiedInputFieldView: View {
  @Binding var query: String
  var isSearchMode: Bool = true
  @FocusState.Binding var isFocused: Bool

  @Environment(AppState.self) private var appState
  @Environment(ContentManager.self) private var contentManager
  @State private var dictationManager = DictationManager.shared
  
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
    // Use TextKit to measure exact wrapped height for the given width and font.
    // Keep existing UX constraints: minimum single-line height and ~4-line cap.
    let baseHeight: CGFloat = 20   // Minimum height for a single line
    let maxHeight: CGFloat = 80    // Cap at ~4 lines (matches existing behavior)

    guard !text.isEmpty, width > 0 else {
      return baseHeight
    }

    let font = NSFont.systemFont(ofSize: 13)

    // Configure paragraph for word-wrapping similar to TextEditor
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byWordWrapping
    paragraph.alignment = .natural

    let attributed = NSAttributedString(
      string: text,
      attributes: [
        .font: font,
        .paragraphStyle: paragraph
      ]
    )

    let storage = NSTextStorage(attributedString: attributed)
    let layoutManager = NSLayoutManager()
    let container = NSTextContainer(size: CGSize(width: max(1, width), height: .greatestFiniteMagnitude))
    // Match NSTextView defaults: keep a small line fragment padding so measurement
    // behaves like TextEditor. This aligns with AppKit's default of ~5pt.
    container.lineFragmentPadding = 5
    container.maximumNumberOfLines = 0

    layoutManager.addTextContainer(container)
    storage.addLayoutManager(layoutManager)

    // Ensure glyph layout, then measure the used rect
    _ = layoutManager.glyphRange(for: container)
    var measured = ceil(layoutManager.usedRect(for: container).height)

    // Removed problematic trailing newline handling that was causing double newlines

    // Enforce min and max heights
    if measured < baseHeight { measured = baseHeight }
    if measured > maxHeight { measured = maxHeight }

    return measured
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
        // Single-line TextField for search mode with custom placeholder and clear button
        ZStack(alignment: .leading) {
          HStack(spacing: 0) {
            TextField("", text: $query, axis: .horizontal)
              .textFieldStyle(.plain)
              .focused($isFocused)
              .disableAutocorrection(true)
              .lineLimit(1)
              .font(.system(size: 13))
              .onSubmit {
                handleSubmit()
              }
              .onKeyPress(keys: [.escape]) { _ in
                if dictationManager.isRecording {
                  Task {
                    await dictationManager.cancelDictation()
                  }
                  return .handled
                }
                return .ignored
              }
              .onKeyPress { keyPress in
                // Handle Cmd+Z for undo enhancement
                if keyPress.key == "z" && keyPress.modifiers.contains(.command) && !keyPress.modifiers.contains(.shift) {
                  if appState.canUndoEnhancement {
                    appState.undoEnhancement()
                    return .handled
                  }
                }
                return .ignored
              }
              .onChange(of: query) { oldValue, newValue in
                handleQueryChange(oldValue: oldValue, newValue: newValue)
              }
            
            // Clear button for search mode
            if !query.isEmpty {
              Button(action: {
                query = ""
                isFocused = true
              }) {
                Image(systemName: "xmark.circle.fill")
                  .font(.system(size: 12))
                  .foregroundColor(.secondary)
                  .opacity(0.6)
              }
              .buttonStyle(PlainButtonStyle())
              .help("Clear")
              .padding(.leading, 4)
            }
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
        // Multi-line TextEditor for prompt mode with scrolling and clear button
        GeometryReader { geometry in
          ZStack(alignment: .topLeading) {
            HStack(alignment: .top, spacing: 0) {
              TextEditor(text: $query)
                .focused($isFocused)
                .disableAutocorrection(true)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(height: textHeight)  // Dynamic height based on content
                .onChange(of: query) { oldValue, newValue in
                  textHeight = calculateTextHeight(newValue, width: geometry.size.width - 20) // Account for clear button space
                  handleQueryChange(oldValue: oldValue, newValue: newValue)
                }
                .onChange(of: geometry.size.width) { _, newWidth in
                  fieldWidth = newWidth
                  textHeight = calculateTextHeight(query, width: newWidth - 20) // Account for clear button space
                }
                .onKeyPress(keys: [.return]) { keyPress in
                  if dictationManager.isRecording {
                    // Enter key while recording - confirm and save transcription
                    Task {
                      await dictationManager.stopDictation(saveTranscription: true)
                    }
                    return .handled
                  } else if keyPress.modifiers.contains(.shift) {
                    // Let TextEditor handle Shift+Enter naturally (creates newline)
                    return .ignored
                  } else if keyPress.modifiers.contains(.command) {
                    // Command+Enter - submit (swapped behavior)
                    handleSubmit()
                    return .handled
                  } else {
                    // Plain Enter - perform combined paste (swapped behavior)
                    // Only if we have content to combine
                    if !ContentManager.shared.selectedItems.isEmpty || !appState.promptText.isEmpty {
                      appState.performCombinedPaste()
                      return .handled
                    }
                    return .ignored
                  }
                }
                .onKeyPress(keys: [.escape]) { _ in
                  if dictationManager.isRecording {
                    // Escape key while recording - cancel transcription
                    Task {
                      await dictationManager.cancelDictation()
                    }
                    return .handled
                  }
                  return .ignored
                }
                .onKeyPress { keyPress in
                  // Handle Cmd+Z for undo enhancement
                  if keyPress.key == "z" && keyPress.modifiers.contains(.command) && !keyPress.modifiers.contains(.shift) {
                    if appState.canUndoEnhancement {
                      appState.undoEnhancement()
                      return .handled
                    }
                  }
                  return .ignored
                }
                .onAppear {
                  fieldWidth = geometry.size.width
                  textHeight = calculateTextHeight(query, width: geometry.size.width - 20) // Account for clear button space
                }
              
              // Clear button for prompt mode - positioned at top right
              if !query.isEmpty {
                VStack {
                  Button(action: {
                    query = ""
                    isFocused = true
                  }) {
                    Image(systemName: "xmark.circle.fill")
                      .font(.system(size: 12))
                      .foregroundColor(.secondary)
                      .opacity(0.6)
                  }
                  .buttonStyle(PlainButtonStyle())
                  .help("Clear")
                  .padding(.top, 2)
                  
                  Spacer()
                }
                .padding(.leading, 4)
              }
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
    // Clear enhancement undo buffer when user manually edits the text
    if appState.originalPromptBeforeEnhancement != nil && newValue != appState.originalPromptBeforeEnhancement {
      appState.originalPromptBeforeEnhancement = nil
    }
  }
  
  @MainActor
  private func handleSubmit() {
    // let _ = query.trimmingCharacters(in: .whitespacesAndNewlines) // trimming not used here currently
    
    // Handle Prompts source specially
    if contentManager.activeSourceId == "prompts" {
      // Apply the first matching prompt
      if let first = contentManager.activeItems.first, 
         let url = first.fileURL {
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
