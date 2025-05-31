import SwiftUI

struct UnifiedInputFieldView: View {
  @Binding var query: String
  var isSearchMode: Bool = true
  @FocusState.Binding var isFocused: Bool

  @Environment(AppState.self) private var appState
  
  private var placeholderText: String {
    if isSearchMode {
      return NSLocalizedString("search_placeholder", comment: "")
    } else {
      return NSLocalizedString("prompt_placeholder", comment: "")
    }
  }
  
  private var currentHeight: CGFloat {
    if isSearchMode {
      return 25
    } else if query.isEmpty {
      return 25 // Start with single line
    } else {
      // Expand based on content
      let lines = query.components(separatedBy: .newlines).count
      let wrappedLines = estimateWrappedLines(for: query)
      let totalLines = max(lines, wrappedLines)
      return min(CGFloat(25 + (totalLines - 1) * 18), 80)
    }
  }
  
  private func estimateWrappedLines(for text: String) -> Int {
    // Rough estimate based on character count and typical line width
    let charactersPerLine = 50
    let totalCharacters = text.count
    return max(1, (totalCharacters + charactersPerLine - 1) / charactersPerLine)
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 5) {
        // Magnifying glass icon (only visible in search mode)
        if isSearchMode {
          Image(systemName: "magnifyingglass")
            .frame(width: 11, height: 11)
            .foregroundColor(.secondary)
            .opacity(0.8)
            .transition(.opacity.animation(.easeInOut(duration: 0.15)))
        }
        
        // Single TextField that adapts based on mode
        TextField(placeholderText, text: $query, axis: isSearchMode ? .horizontal : .vertical)
          .textFieldStyle(.plain)
          .focused($isFocused)
          .disableAutocorrection(true)
          .lineLimit(isSearchMode ? 1...1 : 1...4)
          .onSubmit {
            if isSearchMode || !query.contains("\n") {
              appState.select()
            }
          }
        
        // Clear button
        if !query.isEmpty {
          Button(action: {
            if isSearchMode {
              appState.history.searchQuery = ""
            } else {
              appState.promptText = ""
            }
            isFocused = true
          }) {
            Image(systemName: "xmark.circle.fill")
              .frame(width: 14, height: 14)
              .foregroundColor(.secondary)
          }
          .buttonStyle(PlainButtonStyle())
        }
      }
      .frame(height: currentHeight)
      .padding(.horizontal, 10)
      .animation(.easeInOut(duration: 0.15), value: currentHeight)
      .animation(.easeInOut(duration: 0.15), value: isSearchMode)
      
      // Divider line at the bottom  
      Rectangle()
        .fill(Color.secondary.opacity(0.3))
        .frame(height: 1)
    }
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
      query: .constant("This is a longer prompt that might wrap to multiple lines"),
      isSearchMode: false,
      isFocused: $focused
    )
  }
  .frame(width: 400)
  .padding()
  .background(Color(NSColor.windowBackgroundColor))
  .environment(AppState.shared)
}