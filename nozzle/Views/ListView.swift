import Defaults
import SwiftUI

/// Configuration for ListView behavior
struct ListViewConfiguration {
    let showPinnedSections: Bool
    let enablePopupResize: Bool
    let enableScrollTargeting: Bool
    let enableScenePhaseHandling: Bool
    let showSectionHeaders: Bool
    let contextSectionTitle: String?
    let examplesSectionTitle: String?
    
    static let clipboard = ListViewConfiguration(
        showPinnedSections: true,
        enablePopupResize: true,
        enableScrollTargeting: true,
        enableScenePhaseHandling: true,
        showSectionHeaders: false,
        contextSectionTitle: nil,
        examplesSectionTitle: nil
    )
    
    static let universal = ListViewConfiguration(
        showPinnedSections: false,
        enablePopupResize: false,
        enableScrollTargeting: false,
        enableScenePhaseHandling: false,
        showSectionHeaders: false,
        contextSectionTitle: nil,
        examplesSectionTitle: nil
    )
    
    static let selectedItems = ListViewConfiguration(
        showPinnedSections: false,
        enablePopupResize: false,
        enableScrollTargeting: false,
        enableScenePhaseHandling: false,
        showSectionHeaders: true,
        contextSectionTitle: "Context",
        examplesSectionTitle: "Examples"
    )
}

/// Unified list view that handles all content types
struct ListView: View {
    let configuration: ListViewConfiguration
    
    // Data sources - at most one should be non-empty
    let historyItems: [HistoryItemDecorator]
    let universalItems: [UniversalItemDecorator]
    let contextItems: [UniversalItemDecorator]
    let exampleItems: [UniversalItemDecorator]
    
    // Bindings for clipboard-specific features
    let searchQuery: Binding<String>?
    let searchFocused: FocusState<Bool>.Binding?
    
    @Environment(AppState.self) private var appState
    @Environment(ModifierFlags.self) private var modifierFlags
    @Environment(ContentManager.self) private var contentManager
    @Environment(\.scenePhase) private var scenePhase
    
    @Default(.pinTo) private var pinTo
    @Default(.previewDelay) private var previewDelay
    
    // Computed properties for pinned items (clipboard only)
    private var pinnedItems: [HistoryItemDecorator] {
        guard configuration.showPinnedSections else { return [] }
        return historyItems.filter(\.isPinned).filter(\.isVisible)
    }
    
    private var unpinnedItems: [HistoryItemDecorator] {
        guard configuration.showPinnedSections else { return historyItems.filter(\.isVisible) }
        return historyItems.filter { !$0.isPinned }.filter(\.isVisible)
    }
    
    private var showPinsSeparator: Bool {
        guard configuration.showPinnedSections else { return false }
        return !pinnedItems.isEmpty && !unpinnedItems.isEmpty && (searchQuery?.wrappedValue.isEmpty ?? true)
    }
    
    // Convenience init for clipboard use
    init(
        historyItems: [HistoryItemDecorator],
        searchQuery: Binding<String>,
        searchFocused: FocusState<Bool>.Binding
    ) {
        self.configuration = .clipboard
        self.historyItems = historyItems
        self.universalItems = []
        self.contextItems = []
        self.exampleItems = []
        self.searchQuery = searchQuery
        self.searchFocused = searchFocused
    }
    
    // Convenience init for universal use
    init(universalItems: [UniversalItemDecorator]) {
        self.configuration = .universal
        self.historyItems = []
        self.universalItems = universalItems
        self.contextItems = []
        self.exampleItems = []
        self.searchQuery = nil
        self.searchFocused = nil
    }
    
    // Convenience init for selected items
    init(contextItems: [UniversalItemDecorator], exampleItems: [UniversalItemDecorator]) {
        self.configuration = .selectedItems
        self.historyItems = []
        self.universalItems = []
        self.contextItems = contextItems
        self.exampleItems = exampleItems
        self.searchQuery = nil
        self.searchFocused = nil
    }
    
    var body: some View {
        ScrollView {
            ScrollViewReader { proxy in
                LazyVStack(spacing: 0) {
                    // Clipboard: Show pinned items at top if configured
                    if configuration.showPinnedSections && pinTo == .top {
                        ForEach(pinnedItems) { item in
                            createItemView(item)
                        }
                        
                        if showPinsSeparator {
                            Divider()
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                        }
                    }
                    
                    // Selected items: Context section
                    if configuration.showSectionHeaders && !contextItems.isEmpty {
                        SectionHeader(title: configuration.contextSectionTitle ?? "Context")
                        ForEach(contextItems) { item in
                            createItemView(item)
                        }
                    }
                    
                    // Selected items: Divider between sections
                    if configuration.showSectionHeaders && !contextItems.isEmpty && !exampleItems.isEmpty {
                        Divider()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                    }
                    
                    // Selected items: Examples section
                    if configuration.showSectionHeaders && !exampleItems.isEmpty {
                        SectionHeader(title: configuration.examplesSectionTitle ?? "Examples")
                        ForEach(exampleItems) { item in
                            createItemView(item)
                        }
                    }
                    
                    // Main content: unpinned clipboard items or universal items
                    if !configuration.showSectionHeaders {
                        let mainItems: [any ListItemDecorator] = configuration.showPinnedSections ? 
                            unpinnedItems : universalItems
                        
                        ForEach(Array(mainItems.enumerated()), id: \.element.id) { _, item in
                            createItemView(item)
                        }
                    }
                    
                    // Clipboard: Show pinned items at bottom if configured
                    if configuration.showPinnedSections && pinTo == .bottom {
                        if showPinsSeparator {
                            Divider()
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                        }
                        
                        ForEach(pinnedItems) { item in
                            createItemView(item)
                        }
                    }
                }
                .task(id: configuration.enableScrollTargeting ? appState.scrollTarget : nil) {
                    guard configuration.enableScrollTargeting,
                          appState.scrollTarget != nil else { return }

                    try? await Task.sleep(for: .milliseconds(10))
                    guard !Task.isCancelled else { return }

                    if let selection = appState.scrollTarget {
                        proxy.scrollTo(selection)
                        appState.scrollTarget = nil
                    }
                }
                .onChange(of: configuration.enableScrollTargeting ? contentManager.focusedItemId : nil) { _, newValue in
                    guard configuration.enableScrollTargeting,
                          appState.isKeyboardNavigating,
                          let id = newValue else { return }
                    withAnimation(.easeInOut(duration: 0.15)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
                .onChange(of: scenePhase) {
                    guard configuration.enableScenePhaseHandling else { return }
                    
                    if scenePhase == .active {
                        searchFocused?.wrappedValue = true
                        HistoryItemDecorator.previewThrottler.minimumDelay = Double(previewDelay) / 1000
                        HistoryItemDecorator.previewThrottler.cancel()
                        appState.isKeyboardNavigating = true
                        // Force selection of first visible item
                        if let firstItem = unpinnedItems.first(where: \.isVisible) ?? pinnedItems.first(where: \.isVisible) {
                            appState.selection = firstItem.id
                        }
                    } else {
                        modifierFlags.flags = []
                        appState.isKeyboardNavigating = true
                    }
                }
                // Calculate the total height inside a scroll view (clipboard only)
                .background {
                    if configuration.enablePopupResize {
                        GeometryReader { geo in
                            Color.clear
                                .task(id: appState.popup.needsResize) {
                                    try? await Task.sleep(for: .milliseconds(10))
                                    guard !Task.isCancelled else { return }

                                    if appState.popup.needsResize {
                                        appState.popup.resize(height: geo.size.height)
                                    }
                                }
                        }
                    }
                }
            }
            .contentMargins(.leading, 10, for: .scrollIndicators)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            // Commit any active rename when clicking empty space in the list
            NotificationCenter.default.post(name: .CommitActiveRename, object: nil)
            // Stop dictation if recording
            if DictationManager.shared.isRecording {
                Task {
                    await DictationManager.shared.stopDictation(saveTranscription: true)
                }
            }
        }
    }
    
    @ViewBuilder
    private func createItemView(_ item: any ListItemDecorator) -> some View {
        if let historyItem = item as? HistoryItemDecorator {
            HistoryItemView(item: historyItem)
                .id(item.id)
        } else if let universalItem = item as? UniversalItemDecorator {
            UniversalItemView(item: universalItem)
                .id(item.id)
        }
    }
}

/// Section header component for selected items view
private struct SectionHeader: View {
    let title: String
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

#Preview("Clipboard") {
    ListView(historyItems: [], searchQuery: .constant(""), searchFocused: FocusState<Bool>().projectedValue)
        .environment(AppState.shared)
        .environment(ContentManager.shared)
        .environment(ModifierFlags())
}

#Preview("Universal") {
    ListView(universalItems: [])
        .environment(AppState.shared)
        .environment(ContentManager.shared)
}

#Preview("Selected Items") {
    ListView(contextItems: [], exampleItems: [])
        .environment(ContentManager.shared)
}
