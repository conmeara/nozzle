import SwiftData
import SwiftUI

struct ContentView: View {
  @State private var appState = AppState.shared
  @State private var modifierFlags = ModifierFlags()
  @State private var scenePhase: ScenePhase = .background
  @State private var selectedTab = "clipboard"

  @FocusState private var inputFocused: Bool
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      KeyHandlingView(searchQuery: $appState.history.searchQuery, searchFocused: $inputFocused) {
        VStack(spacing: 0) {
          // Input field at the top
          UnifiedInputFieldView(
            query: appState.isSearchMode ? $appState.history.searchQuery : $appState.promptText,
            isSearchMode: appState.isSearchMode,
            isFocused: $inputFocused
          )
          .padding(.top, 8)
          .padding(.bottom, 4)
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
          
          // Controls and tab buttons row
          HStack(spacing: 6) {
            // Mode icon (search or plus) that switches mode on click
            Button(action: {
              appState.isSearchMode.toggle()
              inputFocused = true
            }) {
              Image(systemName: appState.isSearchMode ? "magnifyingglass" : "plus.circle")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .opacity(0.8)
            }
            .buttonStyle(PlainButtonStyle())
            .help(appState.isSearchMode ? "Switch to prompt mode" : "Switch to search mode")
            
            // Microphone button (only in prompt mode)
            if !appState.isSearchMode {
              Button(action: {
                // Placeholder for future microphone functionality
              }) {
                Image(systemName: "mic")
                  .font(.system(size: 11))
                  .foregroundColor(.secondary)
                  .opacity(0.8)
              }
              .buttonStyle(PlainButtonStyle())
              .help("Voice input")
            }
            
            // Tab buttons positioned after microphone
            TabButton(title: "#", isSelected: selectedTab == "hashtag") {
              selectedTab = "hashtag"
            }
            
            TabButton(title: "Clipboard", isSelected: selectedTab == "clipboard") {
              selectedTab = "clipboard"
            }
            
            TabButton(title: "+", isSelected: false) {
              // Placeholder for add action
            }
            
            Spacer()
            
            // Clear button (conditional on having content)
            if !appState.history.searchQuery.isEmpty || !appState.promptText.isEmpty {
              Button(action: {
                if appState.isSearchMode {
                  appState.history.searchQuery = ""
                } else {
                  appState.promptText = ""
                }
                inputFocused = true
              }) {
                Image(systemName: "xmark.circle.fill")
                  .font(.system(size: 11))
                  .foregroundColor(.secondary)
                  .opacity(0.8)
              }
              .buttonStyle(PlainButtonStyle())
              .help("Clear")
            }
          }
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background {
            GeometryReader { geo in
              Color.clear
                .task(id: geo.size.height) {
                  appState.popup.headerHeight = geo.size.height
                }
            }
          }
          
          // Divider
          Rectangle()
            .fill(Color.secondary.opacity(0.3))
            .frame(height: 1)

          // Main content area with optional preview pane
          HStack(spacing: 0) {
            // History list
            HistoryListView(
              searchQuery: $appState.history.searchQuery,
              searchFocused: $inputFocused
            )
            .frame(minWidth: 300)
            
            // Preview pane (conditional with fixed width)
            if appState.showPreviewPane {
              Divider()
              
              // Preview pane content
              VStack(alignment: .leading, spacing: 0) {
                if let item = appState.previewItem {
                  ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                      // Image preview
                      if let image = item.thumbnailImage {
                        HStack {
                          Spacer()
                          Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .cornerRadius(6)
                          Spacer()
                        }
                        .padding(.top, 8)
                      }
                      
                      // Text content
                      if !item.text.isEmpty {
                        Text(item.text)
                          .font(.system(size: 13))
                          .textSelection(.enabled)
                          .lineLimit(nil)
                          .multilineTextAlignment(.leading)
                          .frame(maxWidth: .infinity, alignment: .leading)
                          .padding(.horizontal, 12)
                      }
                      
                      // Metadata section
                      VStack(alignment: .leading, spacing: 6) {
                        Divider()
                          .padding(.horizontal, 12)
                        
                        // Application info
                        if let app = item.application {
                          HStack(spacing: 4) {
                            Image(nsImage: item.applicationImage.nsImage)
                              .resizable()
                              .frame(width: 16, height: 16)
                            Text(app)
                              .font(.system(size: 11))
                              .foregroundColor(.secondary)
                          }
                          .padding(.horizontal, 12)
                        }
                        
                        // Copy times
                        HStack {
                          Text("First copied:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                          Text(item.item.firstCopiedAt.formatted())
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        
                        HStack {
                          Text("Last copied:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                          Text(item.item.lastCopiedAt.formatted())
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        
                        // Copy count
                        HStack {
                          Text("Copied:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                          Text("\(item.item.numberOfCopies) time(s)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                      }
                      .padding(.vertical, 8)
                    }
                  }
                } else {
                  // No selection placeholder
                  VStack {
                    Spacer()
                    Text("Select an item to preview")
                      .font(.system(size: 13))
                      .foregroundColor(.secondary)
                    Spacer()
                  }
                  .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
              }
              .frame(width: 400)
            }
          }
        }
      }
    }
    .animation(.default.speed(3), value: appState.history.items)
    .animation(.easeInOut(duration: 0.2), value: appState.searchVisible)
    .animation(.easeInOut(duration: 0.15), value: appState.showPreviewPane)
    .padding(.horizontal, 5)
    .padding(.vertical, appState.popup.verticalPadding)
    .background(
      reduceTransparency ? Color(NSColor.windowBackgroundColor) : Color.clear
    )
    .modifier(LiquidGlassModifier(reduceTransparency: reduceTransparency))
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
      }
    }
    .onMouseMove {
      // Only set to false if it was true (avoid constant updates)
      if appState.isKeyboardNavigating {
        appState.isKeyboardNavigating = false
      }
    }
    .task {
      try? await appState.history.load()
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

// Tab button component
struct TabButton: View {
  let title: String
  let isSelected: Bool
  let action: () -> Void
  
  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(isSelected ? .primary : .secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
          RoundedRectangle(cornerRadius: 4)
            .fill(isSelected ? Color.white : Color.white.opacity(0.6))
        )
    }
    .buttonStyle(PlainButtonStyle())
  }
}

struct LiquidGlassModifier: ViewModifier {
  let reduceTransparency: Bool
  
  func body(content: Content) -> some View {
    if reduceTransparency {
      content
    } else {
      content
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }
  }
}

#Preview {
  ContentView()
    .environment(\.locale, .init(identifier: "en"))
    .modelContainer(Storage.shared.container)
}