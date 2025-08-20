import SwiftData
import SwiftUI

struct ContentView: View {
  @State private var appState = AppState.shared
  @State private var modifierFlags = ModifierFlags()
  @State private var scenePhase: ScenePhase = .background
  @State private var selectedTab = "clipboard"
  @State private var contentManager = ContentManager.shared

  @FocusState private var inputFocused: Bool
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      KeyHandlingView(searchQuery: $appState.history.searchQuery, searchFocused: $inputFocused) {
        VStack(spacing: 0) {
          // Input field at the top
          UnifiedInputFieldView(
            query: appState.isSearchMode
              ? Binding(
                  get: {
                    contentManager.activeSourceId == "clipboard"
                      ? appState.history.searchQuery
                      : (contentManager.sources[contentManager.activeSourceId]?.searchQuery ?? "")
                  },
                  set: { newValue in
                    if contentManager.activeSourceId == "clipboard" {
                      appState.history.searchQuery = newValue
                    } else {
                      contentManager.sources[contentManager.activeSourceId]?.searchQuery = newValue
                    }
                  }
                )
              : $appState.promptText,
            isSearchMode: appState.isSearchMode,
            isFocused: $inputFocused
          )
          .padding(.top, 4)
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
          HStack(spacing: 0) {
            // Icon group with tight spacing
            HStack(spacing: 6) {
              // Mode icon (search or plus) that switches mode on click
              Button(action: {
                appState.isSearchMode.toggle()
                inputFocused = true
              }) {
                Image(systemName: appState.isSearchMode ? "magnifyingglass" : "plus.circle")
                  .font(.system(size: 14))
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
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .opacity(0.8)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Voice input")
              }
              
              
              // Enhance prompt button (only in prompt mode)  
              if !appState.isSearchMode {
                Button(action: {
                  // Placeholder for enhance prompt functionality
                }) {
                  Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .opacity(0.8)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Enhance prompt")
              }
            }
            
            // Padding between icon group and tab group
            Spacer()
              .frame(width: 16)
            
            // Tab group with tight spacing
            HStack(spacing: 4) {
              // Aggregated tab placeholder ("#") - Phase 2
              TabButton(title: "#", isSelected: selectedTab == "aggregated") {
                selectedTab = "aggregated"
                contentManager.activeSourceId = "aggregated"
              }
              
              // Dynamic tabs from sources
              ForEach(contentManager.getAllSources(), id: \.id) { src in
                TabButton(title: src.name, isSelected: selectedTab == src.id) {
                  selectedTab = src.id
                  contentManager.activeSourceId = src.id
                }
              }
              
              // "+" to add a folder source
              TabButton(title: "+", isSelected: false) {
                openFolderPickerAndRegister()
              }
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
                  .font(.system(size: 14))
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
            // Content list based on active source
            if contentManager.activeSourceId == "clipboard" {
              HistoryListView(
                searchQuery: $appState.history.searchQuery,
                searchFocused: $inputFocused
              )
              .frame(minWidth: 300)
            } else if contentManager.activeSourceId == "aggregated" {
              // Phase 2: Aggregated view showing selected items from all sources
              let selectedItems = contentManager.selectedItems
                .map(UniversalItemDecorator.init)
              if selectedItems.isEmpty {
                VStack {
                  Spacer()
                  Text("No items selected")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                  Text("Select items from any source to see them here")
                    .font(.system(size: 12))
                    .foregroundColor(Color.secondary.opacity(0.7))
                  Spacer()
                }
                .frame(minWidth: 300)
              } else {
                UniversalListView(items: selectedItems)
                  .frame(minWidth: 300)
              }
            } else {
              // Non-clipboard sources use UniversalListView
              let items = contentManager.getItems(for: contentManager.activeSourceId)
                .map(UniversalItemDecorator.init)
              UniversalListView(items: items)
                .frame(minWidth: 300)
            }
            
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
                      if !item.text.isEmpty && item.thumbnailImage == nil {
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
                    .padding(.top, 8)
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
              .frame(width: 350)
            }
          }
        }
      }
    }
    .animation(.default.speed(3), value: appState.history.items)
    .animation(.easeInOut(duration: 0.2), value: appState.searchVisible)
    .animation(.easeInOut(duration: 0.15), value: appState.showPreviewPane)
    .padding(.horizontal, 5)
    .padding(.top, appState.popup.verticalPadding)
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
    .environment(contentManager)
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
  
  @MainActor
  private func openFolderPickerAndRegister() {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.prompt = "Select Folder"
    panel.message = "Choose a folder to monitor"
    
    if panel.runModal() == .OK, let url = panel.url {
      // Store the bookmark for persistence
      try? Bookmarks.store(url: url)
      
      // Create and register the source
      let source = FileSystemSource(folderURL: url)
      contentManager.registerSource(source)
      
      // Refresh the source content
      Task {
        await source.refresh()
      }
      
      // Switch to the new tab
      selectedTab = source.id
      contentManager.activeSourceId = source.id
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
        .font(.system(size: 13, weight: .regular))
        .foregroundColor(isSelected ? .primary : .secondary)
        .opacity(isSelected ? 1.0 : 0.8)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
          RoundedRectangle(cornerRadius: 4)
            .fill(isSelected ? Color(NSColor.controlAccentColor).opacity(0.2) : Color(NSColor.quaternaryLabelColor))
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