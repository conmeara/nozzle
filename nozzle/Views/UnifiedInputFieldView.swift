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
      TextField(placeholderText, text: $query, axis: isSearchMode ? .horizontal : .vertical)
        .textFieldStyle(.plain)
        .focused($isFocused)
        .disableAutocorrection(true)
        .lineLimit(isSearchMode ? 1...1 : 1...10)
        .font(.system(size: 14))
        .onSubmit {
          if isSearchMode || !query.contains("\n") {
            appState.select()
          }
        }
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .animation(.easeInOut(duration: 0.15), value: isSearchMode)
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