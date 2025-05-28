import Defaults
import SwiftUI

struct PromptHeaderView: View {
  @FocusState.Binding var promptFocused: Bool
  @Binding var promptText: String

  @Environment(AppState.self) private var appState
  @Environment(\.scenePhase) private var scenePhase

  @Default(.showTitle) private var showTitle

  var body: some View {
    HStack(alignment: .top) {
      if showTitle {
        Text("Maccy")
          .foregroundStyle(.secondary)
          .padding(.top, 5)
      }

      ZStack(alignment: .topLeading) {
        // TextEditor for multi-line input
        TextEditor(text: $promptText)
          .focused($promptFocused)
          .frame(maxWidth: .infinity)
          .frame(height: 60) // Fixed height for multiple lines
          .scrollContentBackground(.hidden)
          .padding(4)
          .background(Color(NSColor.controlBackgroundColor))
          .cornerRadius(6)
          .overlay(
            RoundedRectangle(cornerRadius: 6)
              .stroke(Color(NSColor.separatorColor), lineWidth: 1)
          )
          .font(.system(size: 13))
        
        // Placeholder text when empty
        if promptText.isEmpty {
          Text("prompt_placeholder")
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .allowsHitTesting(false) // Don't interfere with TextEditor
            .font(.system(size: 13))
        }
      }
      .onChange(of: scenePhase) {
        if scenePhase == .background && !promptText.isEmpty {
          promptText = ""
        }
      }
    }
    .frame(height: 70) // Total height including padding
    .padding(.horizontal, 10)
    .padding(.bottom, 5)
    .background {
      GeometryReader { geo in
        Color.clear
          .task(id: geo.size.height) {
            appState.popup.headerHeight = geo.size.height
          }
      }
    }
  }
}