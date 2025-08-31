import SwiftData
import SwiftUI

struct ContentView: View {
  @State private var appState = AppState.shared
  @State private var modifierFlags = ModifierFlags()
  @State private var scenePhase: ScenePhase = .background
  @State private var selectedTab = "clipboard"
  @State private var contentManager = ContentManager.shared
  @State private var dictationManager = DictationManager.shared

  @FocusState private var inputFocused: Bool
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      KeyHandlingView(searchQuery: $appState.history.searchQuery, searchFocused: $inputFocused) {
        VStack(spacing: 0) {
          // Header: chips (prompt mode only), input field, and controls with tabs
          VStack(spacing: 0) {
            if !appState.isSearchMode {
              PromptChipsBarView()
            }

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
            HStack(spacing: 8) {
              // Mode icon (search or plus) that switches mode on click
              Button(action: {
                if appState.isSearchMode {
                  // In search mode, this acts as a switch to prompt mode
                    appState.isSearchMode = false
                    inputFocused = true
                } else {
                  // In prompt mode, toggle between Prompts and previous tab
                  if contentManager.activeSourceId == "prompts" {
                    // Already in prompts, return to previous tab
                    selectedTab = contentManager.lastNonPromptsSourceId
                    contentManager.activeSourceId = contentManager.lastNonPromptsSourceId
                  } else {
                    // Not in prompts, open Prompts and save current tab
                    contentManager.lastNonPromptsSourceId = contentManager.activeSourceId
                    selectedTab = "prompts"
                    contentManager.activeSourceId = "prompts"
                  }
                  inputFocused = true
                }
              }) {
                Image(systemName: appState.isSearchMode ? "magnifyingglass" : "plus.circle")
                  .font(.system(size: 14))
                  .foregroundColor(
                    appState.isSearchMode ? .secondary : (contentManager.activeSourceId == "prompts" ? Color(NSColor.controlAccentColor) : .secondary)
                  )
                  .opacity(0.9)
              }
              .buttonStyle(PlainButtonStyle())
              .help(appState.isSearchMode ? "Switch to prompt mode" : "Open Prompts")
              
              // Microphone button (only in prompt mode)
              if !appState.isSearchMode {
                Button(action: {
                  Task { @MainActor in
                    await dictationManager.toggleDictation(for: $appState.promptText)
                  }
                }) {
                  Image(systemName: dictationManager.isRecording ? "mic.fill" : "mic")
                    .font(.system(size: 15))
                    .foregroundColor(dictationManager.isRecording ? .orange : .secondary)
                    .opacity(dictationManager.isRecording ? 1.0 : 0.8)
                    .padding(.all, 2)
                }
                .buttonStyle(PlainButtonStyle())
                .help(dictationManager.isRecording ? "Stop dictation (fn)" : "Start dictation (fn)")
              }
              
              
              // Enhance prompt button (only in prompt mode)  
              if !appState.isSearchMode {
                Button(action: {
                  // Placeholder for enhance prompt functionality
                }) {
                  Image(systemName: "sparkles")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .opacity(0.8)
                    .padding(.all, 2)
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
              // Aggregated tab with icon and badge
              TabButtonWithIcon(
                icon: "square.stack.3d.up.badge.automatic.fill",
                badgeCount: contentManager.selectedItems.count,
                isSelected: selectedTab == "aggregated"
              ) {
                selectedTab = "aggregated"
                contentManager.activeSourceId = "aggregated"
              }
              
              // Dynamic tabs from sources (exclude Prompts)
              ForEach(contentManager.getAllSources().filter { $0.id != "prompts" }, id: \.id) { src in
                TabButton(
                  title: src.name,
                  isSelected: selectedTab == src.id,
                  showCloseButton: src.type == .folder,
                  action: {
                    selectedTab = src.id
                    contentManager.activeSourceId = src.id
                  },
                  onClose: src.type == .folder ? {
                    // Remove the folder source
                    contentManager.removeSource(src.id)
                    
                    // Update selected tab if we just removed the active one
                    if selectedTab == src.id {
                      selectedTab = "clipboard"
                    }
                  } : nil
                )
              }
              
              // "+" menu to add folder source
              Menu {
                Button("Add Folder…") {
                  openFolderPickerAndRegister()
                }
              } label: {
                HStack(spacing: 4) {
                  Text("+")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
                    .opacity(0.8)
                    .lineLimit(1)
                    .truncationMode(.tail)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                  RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.quaternaryLabelColor))
                )
              }
              .buttonStyle(PlainButtonStyle())
              .menuStyle(BorderlessButtonMenuStyle())
              .menuIndicator(.hidden)
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
          }
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
              ListView(
                historyItems: appState.history.items.filter(\.isVisible),
                searchQuery: $appState.history.searchQuery,
                searchFocused: $inputFocused
              )
              .frame(minWidth: 300)
            } else if contentManager.activeSourceId == "aggregated" {
              // Aggregated view showing selected items from all sources, split into Context and Examples
              let contextItems = contentManager.selectedContextItems.map(UniversalItemDecorator.init)
              let exampleItems = contentManager.selectedExampleItems.map(UniversalItemDecorator.init)
              if contextItems.isEmpty && exampleItems.isEmpty {
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
                ListView(contextItems: contextItems, exampleItems: exampleItems)
                  .frame(minWidth: 300)
              }
            } else {
              // Non-clipboard sources use unified ListView
              let items = contentManager.getItems(for: contentManager.activeSourceId)
                .map(UniversalItemDecorator.init)
              ListView(universalItems: items)
                .frame(minWidth: 300)
            }
            
            // Preview pane (conditional with fixed width)
            if appState.showPreviewPane {
              Divider()
              
              // Gate preview by active tab so it always matches the visible list
              PreviewPaneView(
                clipboardItem: contentManager.activeSourceId == "clipboard" ? appState.previewItem : nil,
                fileItem: contentManager.activeSourceId == "clipboard" ? nil : contentManager.focusedContentItem
              )
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
    .onChange(of: contentManager.activeSourceId) { _, newSourceId in
      // Sync selectedTab when activeSourceId changes (e.g., from "/" shortcut)
      selectedTab = newSourceId
      // Ensure an active row is highlighted immediately in the new tab
      appState.isKeyboardNavigating = true
      appState.hoveredListItemId = nil
      if newSourceId == "clipboard" {
        if let first = appState.history.items.first(where: \.isVisible) {
          appState.selection = first.id
        }
      } else if newSourceId == "aggregated" {
        // Selected Items view: focus first context item, else first example item
        let ctx = contentManager.selectedContextItems
        let ex = contentManager.selectedExampleItems
        if let first = (ctx.first ?? ex.first) {
          contentManager.focus(first.id)
        } else {
          contentManager.focus(nil)
        }
      } else {
        // Universal sources (including Prompts): focus first visible item
        let items = contentManager.getItems(for: newSourceId).filter(\.isVisible)
        if let first = items.first {
          contentManager.focus(first.id)
        } else {
          contentManager.focus(nil)
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
    // Re-focus input when requested (e.g., after selecting a prompt)
    .onReceive(NotificationCenter.default.publisher(for: AppState.focusInputNotification)) { _ in
      inputFocused = true
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
      
      // Refresh the source content and start monitoring
      Task {
        await source.refresh()
        source.startMonitoring()
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
  let showCloseButton: Bool
  let action: () -> Void
  let onClose: (() -> Void)?
  
  init(title: String, isSelected: Bool, showCloseButton: Bool = false, action: @escaping () -> Void, onClose: (() -> Void)? = nil) {
    self.title = title
    self.isSelected = isSelected
    self.showCloseButton = showCloseButton
    self.action = action
    self.onClose = onClose
  }
  
  var body: some View {
    HStack(spacing: 4) {
      Button(action: action) {
        HStack(spacing: 4) {
          Text(title)
            .font(.system(size: 13, weight: .regular))
            .foregroundColor(isSelected ? .primary : .secondary)
            .opacity(isSelected ? 1.0 : 0.8)
            .lineLimit(1)
            .truncationMode(.tail)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
          RoundedRectangle(cornerRadius: 8)
            .fill(
              isSelected
                ? Color(NSColor.controlAccentColor).opacity(0.20)
                : Color(NSColor.quaternaryLabelColor)
            )
        )
      }
      .buttonStyle(PlainButtonStyle())
      // Right-click context menu for deletable tabs
      .contextMenu {
        if showCloseButton {
          Button(action: { onClose?() }) {
            Label("Close Tab", systemImage: "xmark")
          }
        }
      }
    }
  }
}

// Reusable tab button label for consistent styling
struct TabButtonLabel: View {
  let title: String
  let isSelected: Bool
  
  var body: some View {
    HStack(spacing: 4) {
      Text(title)
        .font(.system(size: 13, weight: .regular))
        .foregroundColor(isSelected ? .primary : .secondary)
        .opacity(isSelected ? 1.0 : 0.8)
        .lineLimit(1)
        .truncationMode(.tail)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(
          isSelected
            ? Color(NSColor.controlAccentColor).opacity(0.20)
            : Color(NSColor.quaternaryLabelColor)
        )
    )
  }
}

// Tab button with icon and badge count
struct TabButtonWithIcon: View {
  let icon: String
  let badgeCount: Int
  let isSelected: Bool
  let action: () -> Void
  
  var body: some View {
    Button(action: action) {
      HStack(spacing: 4) {
        // Use base SF Symbol with overlay badge when count > 0
        ZStack {
          Image(systemName: badgeCount > 0 ? "square.stack.3d.up.fill" : "square.stack.3d.up")
            .font(.system(size: 13))
            .foregroundColor(isSelected ? .primary : .secondary)
            .opacity(isSelected ? 1.0 : 0.8)
          
          // Native SF Symbol-style badge overlay (bottom-right position)
          if badgeCount > 0 {
            Text(badgeCount > 99 ? "99+" : "\(badgeCount)")
              .font(.system(size: 7, weight: .bold))
              .foregroundColor(.white)
              .padding(.horizontal, badgeCount > 9 ? 2.5 : 3)
              .padding(.vertical, 1.5)
              .background(Color(NSColor.systemGray))
              .clipShape(Circle())
              .offset(x: 7, y: 7)
              .scaleEffect(0.75)
          }
        }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(
            isSelected
              ? Color(NSColor.controlAccentColor).opacity(0.20)
              : Color(NSColor.quaternaryLabelColor)
          )
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
        .glassEffect(.regular, in: .rect(cornerRadius: DesignConstants.cornerRadius))
    }
  }
}

#Preview {
  ContentView()
    .environment(\.locale, .init(identifier: "en"))
    .modelContainer(Storage.shared.container)
}
