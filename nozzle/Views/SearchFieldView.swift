import SwiftUI

struct SearchFieldView: View {
  var placeholder: LocalizedStringKey
  @Binding var query: String
  var isSearchMode: Bool = true  // Default to search mode for backward compatibility

  @Environment(AppState.self) private var appState

  private var effectivePlaceholder: LocalizedStringKey {
    isSearchMode ? placeholder : "prompt_placeholder"
  }

  var body: some View {
    VStack(spacing: 0) {
      ZStack(alignment: .topLeading) {
        // Background and border
        RoundedRectangle(cornerRadius: 6)
          .fill(Color(NSColor.controlBackgroundColor))
          .overlay(
            RoundedRectangle(cornerRadius: 6)
              .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 1)
          )
        
        // Content
        HStack(alignment: isSearchMode ? .center : .top, spacing: 8) {
          // Magnifying glass icon (only visible in search mode)
          if isSearchMode {
            Image(systemName: "magnifyingglass")
              .frame(width: 11, height: 11)
              .foregroundColor(.secondary)
              .padding(.leading, 8)
              .padding(.top, isSearchMode ? 0 : 8)
              .transition(.scale.combined(with: .opacity))
          }
          
          // Input field
          if isSearchMode {
            // Single-line TextField for search
            TextField(effectivePlaceholder, text: $query)
              .disableAutocorrection(true)
              .lineLimit(1)
              .textFieldStyle(.plain)
              .padding(.vertical, 6)
              .padding(.trailing, 8)
              .onSubmit {
                appState.select()
              }
          } else {
            // Multi-line TextEditor for prompt
            TextEditor(text: $query)
              .scrollContentBackground(.hidden)
              .background(Color.clear)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .font(.system(size: 13))
          }
          
          // Clear button
          if !query.isEmpty {
            Button {
              query = ""
            } label: {
              Image(systemName: "xmark.circle.fill")
                .frame(width: 11, height: 11)
                .foregroundColor(.secondary.opacity(0.6))
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.trailing, 8)
            .padding(.top, isSearchMode ? 0 : 6)
          }
        }
        
        // Placeholder overlay for prompt mode
        if !isSearchMode && query.isEmpty {
          Text(effectivePlaceholder)
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .allowsHitTesting(false)
            .font(.system(size: 13))
        }
      }
      .frame(height: isSearchMode ? 30 : 60)
      .animation(.easeInOut(duration: 0.2), value: isSearchMode)
      
      // Divider line at the bottom
      Rectangle()
        .fill(Color.secondary.opacity(0.3))
        .frame(height: 1)
    }
  }
}

#Preview {
  return List {
    SearchFieldView(placeholder: "search_placeholder", query: .constant(""))
    SearchFieldView(placeholder: "search_placeholder", query: .constant("search"))
  }
  .frame(width: 300)
  .environment(\.locale, .init(identifier: "en"))
}
