import SwiftData
import SwiftUI

struct ContentView: View {
  @State private var appState = AppState.shared
  @State private var modifierFlags = ModifierFlags()
  @State private var scenePhase: ScenePhase = .background
  @State private var selectedTab = "clipboard"
  @State private var contentManager = ContentManager.shared
  @State private var dictationManager = DictationManager.shared
  @State private var renameCatcher = RenameEventCatcher()
  @State private var hostWindow: NSWindow?
  
  // Tab pagination state
  @State private var currentTabPage = 0
  @State private var tabsPerPage = 5
  @State private var availableTabWidth: CGFloat = 400
  @State private var pageBreaks: [Int] = [0] // Start indices of each page
  @State private var tabWidthCache: [String: CGFloat] = [:] // Cache for tab width calculations
  @State private var updateTabsTask: Task<Void, Never>? // Debouncing task

  @FocusState private var inputFocused: Bool
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  
  // Tab pagination computed properties
  private var maxTabWidth: CGFloat { 120 }
  private var tabSpacing: CGFloat { 4 }
  private var navigationButtonWidth: CGFloat { 32 }
  private var aggregatedTabWidth: CGFloat { 32 }
  
  // Calculate approximate width needed for a tab based on its title
  private func calculateTabWidth(for title: String) -> CGFloat {
    // Check cache first
    if let cachedWidth = tabWidthCache[title] {
      return cachedWidth
    }
    
    // Calculate if not cached (fallback for any calls outside updateTabsPerPage)
    let avgCharWidth: CGFloat = 7.5
    let paddingHorizontal: CGFloat = 16 // 8px on each side
    let baseWidth = CGFloat(title.count) * avgCharWidth + paddingHorizontal
    
    // Apply max width limit but allow natural sizing below it
    return min(baseWidth, maxTabWidth)
  }
  
  private var allTabs: [any ContentSource] {
    contentManager.getAllSources().filter { $0.id != "prompts" }
  }
  
  private var totalPages: Int {
    max(1, pageBreaks.count)
  }
  
  private var visibleTabsForCurrentPage: [any ContentSource] {
    guard currentTabPage < pageBreaks.count else { return [] }
    
    let startIndex = pageBreaks[currentTabPage]
    let endIndex: Int
    
    if currentTabPage + 1 < pageBreaks.count {
      endIndex = pageBreaks[currentTabPage + 1]
    } else {
      endIndex = allTabs.count
    }
    
    return Array(allTabs[startIndex..<endIndex])
  }
  
  private var hasMorePages: Bool {
    currentTabPage < totalPages - 1
  }
  
  private var showLeftNavButton: Bool {
    currentTabPage > 0
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      KeyHandlingView(
        searchQuery: $appState.history.searchQuery,
        searchFocused: $inputFocused,
        currentTabPage: $currentTabPage,
        totalPages: totalPages
      ) {
        VStack(spacing: 0) {
          // Header: chips (always show when present), input field, and controls with tabs
          VStack(spacing: 0) {
            if !appState.promptChips.isEmpty {
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
            .padding(.horizontal, 2)
            .padding(.top, 6)
            .padding(.bottom, 6)
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
            HStack(alignment: .center, spacing: 0) {
            // Icon group with tight spacing
            HStack(spacing: 8) {
              // Mode icon (search or plus) that switches mode on click
              Button(action: {
                if appState.isSearchMode {
                  // In search mode, this acts as a switch to prompt mode
                    appState.isSearchMode = false
                    Task { @MainActor in
                      try? await Task.sleep(for: .milliseconds(50))
                      inputFocused = true
                    }
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
                  Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(50))
                    inputFocused = true
                  }
                }
              }) {
                Image(systemName: "plus.circle")
                  .font(.system(size: 14))
                  .foregroundColor(
                    appState.isSearchMode ? .secondary : (contentManager.activeSourceId == "prompts" ? Color(NSColor.controlAccentColor) : .secondary)
                  )
                  .opacity(appState.isSearchMode ? 0.5 : 0.9)
                  .animation(.easeInOut(duration: 0.2), value: appState.isSearchMode)
              }
              .buttonStyle(PlainButtonStyle())
              .help(appState.isSearchMode ? "Exit search mode" : "Open Prompts")
              .contextMenu {
                if !appState.isSearchMode {
                  Button("New") {
                    (contentManager.sources["prompts"] as? PromptsSource)?.createNewPrompt()
                  }
                  
                  Button("Add") {
                    let currentText = appState.promptText
                    if !currentText.isEmpty {
                      (contentManager.sources["prompts"] as? PromptsSource)?.createNewPrompt(initialContents: currentText)
                    }
                  }
                  
                  Divider()
                  
                  Button("Open Prompts") {
                    if contentManager.activeSourceId != "prompts" {
                      contentManager.lastNonPromptsSourceId = contentManager.activeSourceId
                      selectedTab = "prompts"
                      contentManager.activeSourceId = "prompts"
                    }
                  }
                }
              }
              
              // Microphone button
              Button(action: {
                if appState.isSearchMode {
                  // Exit search mode
                  appState.isSearchMode = false
                  Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(50))
                    inputFocused = true
                  }
                } else {
                  Task { @MainActor in
                    await dictationManager.toggleDictation(for: $appState.promptText)
                  }
                }
              }) {
                Image(systemName: dictationManager.isRecording ? "mic.fill" : "mic")
                  .font(.system(size: 15))
                  .foregroundColor(dictationManager.isRecording ? .orange : .secondary)
                  .opacity(appState.isSearchMode ? 0.5 : (dictationManager.isRecording ? 1.0 : 0.8))
                  .animation(.easeInOut(duration: 0.2), value: appState.isSearchMode)
                  .padding(.all, 2)
              }
              .buttonStyle(PlainButtonStyle())
              .help(appState.isSearchMode ? "Exit search mode" : (dictationManager.isRecording ? "Stop dictation (fn)" : "Start dictation (fn)"))
              
              
              // Enhance prompt button
              Button(action: {
                if appState.isSearchMode {
                  // Exit search mode
                  appState.isSearchMode = false
                  Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(50))
                    inputFocused = true
                  }
                } else {
                  // Placeholder for enhance prompt functionality
                }
              }) {
                Image(systemName: "sparkles")
                  .font(.system(size: 15))
                  .foregroundColor(.secondary)
                  .opacity(appState.isSearchMode ? 0.5 : 0.8)
                  .animation(.easeInOut(duration: 0.2), value: appState.isSearchMode)
                  .padding(.all, 2)
              }
              .buttonStyle(PlainButtonStyle())
              .help(appState.isSearchMode ? "Exit search mode" : "Enhance prompt")
            }
            
            // Padding between icon group and tab group
            Spacer()
              .frame(width: 16)
            
            // Tab group with pagination
            GeometryReader { geometry in
              VStack {
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                // Always visible: Aggregated tab
                TabButtonWithIcon(
                  icon: "square.stack.3d.up.badge.automatic.fill",
                  badgeCount: contentManager.selectedItems.count,
                  isSelected: selectedTab == "aggregated"
                ) {
                  selectedTab = "aggregated"
                  contentManager.activeSourceId = "aggregated"
                  // Refresh file sources if needed when viewing aggregated
                  Task {
                    for source in contentManager.getAllSources() {
                      if let fileSource = source as? FileSystemSource {
                        await fileSource.refreshIfNeeded()
                      }
                    }
                  }
                }
                
                // Left navigation (visible on page 2+)
                if showLeftNavButton {
                  NavigationTabButton(direction: .left) {
                    withAnimation(.easeInOut(duration: 0.1)) {
                      currentTabPage = max(0, currentTabPage - 1)
                    }
                  }
                }
                
                // Current page tabs
                TabPageContainer(
                  tabs: visibleTabsForCurrentPage,
                  currentPage: currentTabPage,
                  selectedTab: selectedTab,
                  onTabSelect: { tabId, source in
                    selectedTab = tabId
                    contentManager.activeSourceId = tabId
                    // For file tabs, only refresh if data is stale
                    if let fileSource = source as? FileSystemSource {
                      Task {
                        await fileSource.refreshIfNeeded()
                      }
                    }
                  },
                  onTabClose: { source in
                    contentManager.removeSource(source.id)
                    // Handle tab removal and page navigation
                    handleTabRemoval(source.id)
                  }
                )
                
                // Right navigation OR Add button
                if hasMorePages {
                  NavigationTabButton(direction: .right) {
                    withAnimation(.easeInOut(duration: 0.1)) {
                      currentTabPage = min(totalPages - 1, currentTabPage + 1)
                    }
                  }
                } else {
                  // "+" menu styled like navigation buttons
                  Menu {
                    Button("Add Folder…") {
                      openFolderPickerAndRegister()
                    }
                  } label: {
                    HStack(spacing: 4) {
                      Text("+")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.secondary)
                        .opacity(0.8)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .glassEffect(Glass.clear.tint(.white.opacity(0.05)).interactive(), in: .rect(cornerRadius: 8))
                  }
                  .buttonStyle(PlainButtonStyle())
                  .menuStyle(BorderlessButtonMenuStyle())
                  .menuIndicator(.hidden)
                }
              }
                Spacer(minLength: 0)
              }
              .onAppear {
                updateTabsPerPage(availableWidth: geometry.size.width)
              }
              .onChange(of: geometry.size.width) { _, newWidth in
                updateTabsPerPage(availableWidth: newWidth)
              }
              .onDisappear {
                // Clean up debouncing task
                updateTabsTask?.cancel()
                updateTabsTask = nil
              }
            }
            .frame(height: 32)
            
            Spacer()
            }
            .padding(.leading, 8)
            .padding(.trailing, 0)
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
              let contextItems = contentManager.selectedContextDecorators
              let exampleItems = contentManager.selectedExampleDecorators
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
                .frame(minWidth: 300, maxWidth: .infinity)
              } else {
                ListView(contextItems: contextItems, exampleItems: exampleItems)
                  .contextMenu {
                    Button("Copy All") {
                      appState.performCombinedPaste()
                    }
                    
                    Button("Clear Selection") {
                      contentManager.clearSelection()
                      appState.updateFooterItemVisibility()
                    }
                    
                    Divider()
                    
                    if !contextItems.isEmpty {
                      Button("Convert All to Examples") {
                        for item in contextItems {
                          contentManager.toggleExample(item.id)
                        }
                      }
                    }
                    
                    if !exampleItems.isEmpty {
                      Button("Convert All to Context") {
                        for item in exampleItems {
                          contentManager.toggleExample(item.id)
                        }
                      }
                    }
                  }
                  .frame(minWidth: 300)
              }
            } else {
              // Non-clipboard sources use unified ListView with cached decorators
              let items = contentManager.getDecorators(for: contentManager.activeSourceId)
              
              if contentManager.activeSourceId == "prompts" {
                // Wrap entire prompts view in a container with consistent context menu
                ZStack {
                  // Background that fills entire area and responds to right-clicks
                  Color.clear
                    .contentShape(Rectangle())
                  
                  if items.isEmpty {
                    VStack {
                      Spacer()
                      Text("No prompts found")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                      Text("Right-click to create your first prompt")
                        .font(.system(size: 12))
                        .foregroundColor(Color.secondary.opacity(0.7))
                      Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                  } else {
                    ListView(universalItems: items)
                      .frame(minWidth: 300, maxHeight: .infinity)
                  }
                }
                .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
                .contextMenu {
                  Button("New") {
                    (contentManager.sources["prompts"] as? PromptsSource)?.createNewPrompt()
                  }
                  
                  Button("Add") {
                    let currentText = appState.isSearchMode ? appState.history.searchQuery : appState.promptText
                    if !currentText.isEmpty {
                      (contentManager.sources["prompts"] as? PromptsSource)?.createNewPrompt(initialContents: currentText)
                    }
                  }
                }
              } else {
                ListView(universalItems: items)
                  .frame(minWidth: 300)
              }
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
    .background {
      if reduceTransparency {
        Color(NSColor.windowBackgroundColor)
          .clipShape(.rect(cornerRadius: DesignConstants.panelCornerRadius))
      } else {
        Color.clear
      }
    }
    .modifier(LiquidGlassModifier(reduceTransparency: reduceTransparency))
    // Host window accessor for global rename event monitors
    .background(WindowAccessor { win in hostWindow = win })
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
    // Arm/disarm one-shot monitors when inline rename starts/ends
    .onChange(of: contentManager.renameActiveItemId) { _, newValue in
      if let win = hostWindow, newValue != nil {
        if NSApp.modalWindow == nil { renameCatcher.arm(in: win) }
      } else {
        renameCatcher.disarm()
      }
    }
    // Safety: disarm if window resigns key
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
      renameCatcher.disarm()
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
  
  // MARK: - Tab Pagination Helper Functions
  
  private func updateTabsPerPage(availableWidth: CGFloat) {
    // Cancel previous task
    updateTabsTask?.cancel()
    
    // Schedule new debounced task
    updateTabsTask = Task { @MainActor in
      // Wait one frame to batch multiple rapid calls
      try? await Task.sleep(nanoseconds: 16_000_000) // ~16ms = 1 frame at 60fps
      
      // Check if task was cancelled
      guard !Task.isCancelled else { return }
      
      // Perform the actual update
      performUpdateTabsPerPage(availableWidth: availableWidth)
    }
  }
  
  private func performUpdateTabsPerPage(availableWidth: CGFloat) {
    // Populate cache for all tabs first (only calculates for uncached tabs)
    for tab in allTabs {
      if tabWidthCache[tab.name] == nil {
        let avgCharWidth: CGFloat = 7.5
        let paddingHorizontal: CGFloat = 16 // 8px on each side
        let baseWidth = CGFloat(tab.name.count) * avgCharWidth + paddingHorizontal
        tabWidthCache[tab.name] = min(baseWidth, maxTabWidth)
      }
    }
    
    // Calculate available width for tabs (minus fixed elements)
    // Always account for aggregated tab and spacing
    let aggregatedAndSpacing = aggregatedTabWidth + tabSpacing
    
    // Account for left navigation if on page > 0
    let leftNavWidth = currentTabPage > 0 ? navigationButtonWidth + tabSpacing : 0
    
    // First, try to fit all tabs with just the add button
    let addButtonWidth: CGFloat = 40
    var usableWidth = availableWidth - aggregatedAndSpacing - leftNavWidth - addButtonWidth - tabSpacing
    
    // Calculate how many tabs fit (now using cached values)
    var totalTabWidth: CGFloat = 0
    for tab in allTabs {
      totalTabWidth += (tabWidthCache[tab.name] ?? calculateTabWidth(for: tab.name)) + tabSpacing
    }
    
    // If all tabs don't fit, we need pagination, so account for nav buttons instead of add button
    if totalTabWidth > usableWidth {
      // Recalculate with navigation button instead of add button
      let navigationButtonWidth: CGFloat = 32
      usableWidth = availableWidth - aggregatedAndSpacing - leftNavWidth - navigationButtonWidth - tabSpacing
    }
    
    // Calculate page breaks based on actual tab widths
    var pageBreaks: [Int] = [0] // Start of each page
    var currentPageWidth: CGFloat = 0
    var currentPageStartIndex = 0
    
    for (index, tab) in allTabs.enumerated() {
      let tabWidth = tabWidthCache[tab.name] ?? calculateTabWidth(for: tab.name)
      let tabWithSpacing = tabWidth + tabSpacing
      
      // Check if adding this tab would exceed the page width
      if currentPageWidth + tabWithSpacing > usableWidth && index > currentPageStartIndex {
        // Start a new page
        pageBreaks.append(index)
        currentPageStartIndex = index
        currentPageWidth = tabWithSpacing
      } else {
        currentPageWidth += tabWithSpacing
      }
    }
    
    // Store the page breaks and update total pages
    self.pageBreaks = pageBreaks
    let newTotalPages = max(1, pageBreaks.count)
    
    // Ensure current page is still valid
    currentTabPage = min(currentTabPage, newTotalPages - 1)
  }
  
  private func handleTabRemoval(_ removedTabId: String) {
    // Clear cache for the removed tab
    if let source = contentManager.sources[removedTabId] {
      tabWidthCache.removeValue(forKey: source.name)
    }
    
    // Update selected tab if we just removed the active one
    if selectedTab == removedTabId {
      selectedTab = "clipboard"
      contentManager.activeSourceId = "clipboard"
    }
    
    // If current page becomes empty after removal, go to previous page
    if visibleTabsForCurrentPage.isEmpty && currentTabPage > 0 {
      currentTabPage -= 1
    }
  }
  
  private func navigateToPreviousTabPage() {
    if currentTabPage > 0 {
      withAnimation(.easeInOut(duration: 0.1)) {
        currentTabPage -= 1
      }
    }
  }
  
  private func navigateToNextTabPage() {
    if currentTabPage < totalPages - 1 {
      withAnimation(.easeInOut(duration: 0.1)) {
        currentTabPage += 1
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
  let maxWidth: CGFloat?
  let action: () -> Void
  let onClose: (() -> Void)?
  let source: (any ContentSource)?
  
  init(title: String, isSelected: Bool, showCloseButton: Bool = false, maxWidth: CGFloat? = nil, action: @escaping () -> Void, onClose: (() -> Void)? = nil, source: (any ContentSource)? = nil) {
    self.title = title
    self.isSelected = isSelected
    self.showCloseButton = showCloseButton
    self.maxWidth = maxWidth
    self.action = action
    self.onClose = onClose
    self.source = source
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
        .glassEffect(Glass.clear.tint(.white.opacity(0.05)).interactive(), in: .rect(cornerRadius: 8))
      }
      .buttonStyle(PlainButtonStyle())
      // Right-click context menu for deletable tabs
      .contextMenu {
        if let fileSystemSource = source as? FileSystemSource {
          // Enhanced context menu for folder tabs
          Menu("Sort By") {
            Button(fileSystemSource.sortOrder == .name && fileSystemSource.sortDirection == .ascending ? "✓ Name (A-Z)" : "Name (A-Z)") {
              fileSystemSource.setSortOrder(.name, direction: .ascending)
            }
            Button(fileSystemSource.sortOrder == .name && fileSystemSource.sortDirection == .descending ? "✓ Name (Z-A)" : "Name (Z-A)") {
              fileSystemSource.setSortOrder(.name, direction: .descending)
            }
            Button(fileSystemSource.sortOrder == .dateModified && fileSystemSource.sortDirection == .descending ? "✓ Date Modified (Newest First)" : "Date Modified (Newest First)") {
              fileSystemSource.setSortOrder(.dateModified, direction: .descending)
            }
            Button(fileSystemSource.sortOrder == .dateModified && fileSystemSource.sortDirection == .ascending ? "✓ Date Modified (Oldest First)" : "Date Modified (Oldest First)") {
              fileSystemSource.setSortOrder(.dateModified, direction: .ascending)
            }
            Button(fileSystemSource.sortOrder == .size && fileSystemSource.sortDirection == .descending ? "✓ Size (Largest First)" : "Size (Largest First)") {
              fileSystemSource.setSortOrder(.size, direction: .descending)
            }
            Button(fileSystemSource.sortOrder == .size && fileSystemSource.sortDirection == .ascending ? "✓ Size (Smallest First)" : "Size (Smallest First)") {
              fileSystemSource.setSortOrder(.size, direction: .ascending)
            }
            Button(fileSystemSource.sortOrder == .type && fileSystemSource.sortDirection == .ascending ? "✓ Type" : "Type") {
              fileSystemSource.setSortOrder(.type, direction: .ascending)
            }
          }
          
          Divider()
          
          Button("Refresh") {
            Task {
              await fileSystemSource.refresh()
            }
          }
          
          Button("Reveal in Finder") {
            NSWorkspace.shared.open(fileSystemSource.folderURL)
          }
          
          Divider()
          
          Button("Close Tab", role: .destructive) {
            onClose?()
          }
        } else if showCloseButton {
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
    .glassEffect(Glass.clear.tint(.white.opacity(0.05)).interactive(), in: .rect(cornerRadius: 8))
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
      .padding(.vertical, 3.5)
      .glassEffect(Glass.clear.tint(.white.opacity(0.05)).interactive(), in: .rect(cornerRadius: 8))
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
        .glassEffect(.regular, in: .rect(cornerRadius: DesignConstants.panelCornerRadius))
    }
  }
}

// Navigation tab button for pagination
struct NavigationTabButton: View {
  enum Direction {
    case left
    case right
    
    var iconName: String {
      switch self {
      case .left: return "chevron.left"
      case .right: return "chevron.right"
      }
    }
  }
  
  let direction: Direction
  let action: () -> Void
  
  var body: some View {
    Button(action: action) {
      HStack(spacing: 4) {
        Image(systemName: direction.iconName)
          .font(.system(size: 12, weight: .regular))
          .foregroundColor(.secondary)
          .opacity(0.8)
      }
      .padding(.horizontal, 11)
      .padding(.vertical, 6)
      .glassEffect(Glass.clear.tint(.white.opacity(0.05)).interactive(), in: .rect(cornerRadius: 8))
    }
    .buttonStyle(PlainButtonStyle())
    .help(direction == .left ? "Previous page" : "Next page")
  }
}


// Container for paginated tabs with sliding animation
struct TabPageContainer: View {
  let tabs: [any ContentSource]
  let currentPage: Int
  let selectedTab: String
  let onTabSelect: (String, any ContentSource) -> Void
  let onTabClose: ((any ContentSource) -> Void)?
  
  var body: some View {
    HStack(spacing: 4) {
      ForEach(tabs, id: \.id) { source in
        TabButton(
          title: source.name,
          isSelected: selectedTab == source.id,
          showCloseButton: source.type == .folder,
          maxWidth: nil,
          action: {
            onTabSelect(source.id, source)
          },
          onClose: source.type == .folder ? {
            onTabClose?(source)
          } : nil,
          source: source
        )
      }
    }
    // Animation removed - page transitions are already handled by withAnimation in navigation buttons
  }
}

#Preview {
  ContentView()
    .environment(\.locale, .init(identifier: "en"))
    .modelContainer(Storage.shared.container)
}
