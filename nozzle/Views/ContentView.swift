import SwiftData
import SwiftUI

struct ContentView: View {
  @State private var appState = AppState.shared
  @State private var modifierFlags = ModifierFlags()
  @State private var scenePhase: ScenePhase = .background

  @FocusState private var inputFocused: Bool

  var body: some View {
    ZStack {
      VisualEffectView()

      VStack(alignment: .leading, spacing: 0) {
        KeyHandlingView(searchQuery: $appState.history.searchQuery, searchFocused: $inputFocused) {
          VStack(spacing: 0) {
            UnifiedInputFieldView(
              query: appState.isSearchMode ? $appState.history.searchQuery : $appState.promptText,
              isSearchMode: appState.isSearchMode,
              isFocused: $inputFocused
            )
            .padding(.bottom, 5)
            .background {
              GeometryReader { geo in
                Color.clear
                  .task(id: geo.size.height) {
                    appState.popup.headerHeight = geo.size.height
                  }
              }
            }
            .onChange(of: appState.isSearchMode) { _, newValue in
              // Clear search when switching to prompt mode
              if !newValue {
                appState.history.searchQuery = ""
              }
              // Note: We don't clear promptText when switching to search mode
              // so it persists when user switches back
            }
            .onChange(of: scenePhase) {
              if scenePhase == .background {
                if !appState.history.searchQuery.isEmpty {
                  appState.history.searchQuery = ""
                }
                // Note: We don't clear promptText when app closes
                // so it persists when user reopens the app
              }
            }

            HistoryListView(
              searchQuery: $appState.history.searchQuery,
              searchFocused: $inputFocused
            )
          }

          FooterView(footer: appState.footer)
        }
      }
      .animation(.default.speed(3), value: appState.history.items)
      .animation(.easeInOut(duration: 0.2), value: appState.searchVisible)
      .padding(.horizontal, 5)
      .padding(.vertical, appState.popup.verticalPadding)
      .onAppear {
        inputFocused = true
        // Ensure first item is selected on appear
        Task {
          try? await Task.sleep(for: .milliseconds(100))
          if appState.selection == nil,
             let firstItem = appState.history.unpinnedItems.first(where: \.isVisible) ?? appState.history.pinnedItems.first(where: \.isVisible) {
            appState.selection = firstItem.id
            appState.isKeyboardNavigating = true
          }
          appState.updateFooterItemVisibility()
        }
      }
      .onChange(of: appState.promptText) { _, _ in
        appState.updateFooterItemVisibility()
      }
      .onMouseMove {
        appState.isKeyboardNavigating = false
      }
      .task {
        try? await appState.history.load()
      }
    }
    .environment(appState)
    .environment(modifierFlags)
    .environment(\.scenePhase, scenePhase)
    // FloatingPanel is not a scene, so let's implement custom scenePhase..
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) {
      if let window = $0.object as? NSWindow,
         let bundleIdentifier = Bundle.main.bundleIdentifier,
         window.identifier == NSUserInterfaceItemIdentifier(bundleIdentifier) {
        scenePhase = .active
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) {
      if let window = $0.object as? NSWindow,
         let bundleIdentifier = Bundle.main.bundleIdentifier,
         window.identifier == NSUserInterfaceItemIdentifier(bundleIdentifier) {
        scenePhase = .background
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: NSPopover.willShowNotification)) {
      if let popover = $0.object as? NSPopover {
        // Prevent NSPopover from showing close animation when
        // quickly toggling FloatingPanel while popover is visible.
        popover.animates = false
        // Prevent NSPopover from becoming first responder.
        popover.behavior = .semitransient
      }
    }
  }
}

#Preview {
  ContentView()
    .environment(\.locale, .init(identifier: "en"))
    .modelContainer(Storage.shared.container)
}
