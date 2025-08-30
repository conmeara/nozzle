import Defaults
import KeyboardShortcuts
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
  var panel: FloatingPanel<ContentView>!

  @objc
  private lazy var statusItem: NSStatusItem = {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem.behavior = .removalAllowed
    statusItem.button?.action = #selector(performStatusItemClick)
    statusItem.button?.image = Defaults[.menuIcon].image
    statusItem.button?.imagePosition = .imageLeft
    statusItem.button?.target = self
    statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    return statusItem
  }()

  private var isStatusItemDisabled: Bool {
    Defaults[.ignoreEvents] || Defaults[.enabledPasteboardTypes].isEmpty
  }

  private var statusItemVisibilityObserver: NSKeyValueObservation?

  func applicationWillFinishLaunching(_ notification: Notification) { // swiftlint:disable:this function_body_length

    // Bridge FloatingPanel via AppDelegate.
    AppState.shared.appDelegate = self

    Clipboard.shared.onNewCopy { History.shared.add($0) }
    Clipboard.shared.start()

    Task {
      for await _ in Defaults.updates(.clipboardCheckInterval, initial: false) {
        Clipboard.shared.restart()
      }
    }

    statusItemVisibilityObserver = observe(\.statusItem.isVisible, options: .new) { _, change in
      if let newValue = change.newValue, Defaults[.showInStatusBar] != newValue {
        Defaults[.showInStatusBar] = newValue
      }
    }

    Task {
      for await value in Defaults.updates(.showInStatusBar) {
        statusItem.isVisible = value
      }
    }

    Task {
      for await value in Defaults.updates(.menuIcon, initial: false) {
        statusItem.button?.image = value.image
      }
    }

    synchronizeMenuIconText()
    Task {
      for await value in Defaults.updates(.showRecentCopyInMenuBar) {
        if value {
          statusItem.button?.title = AppState.shared.menuIconText
        } else {
          statusItem.button?.title = ""
        }
      }
    }

    Task {
      for await _ in Defaults.updates(.ignoreEvents) {
        statusItem.button?.appearsDisabled = isStatusItemDisabled
      }
    }

    Task {
      for await _ in Defaults.updates(.enabledPasteboardTypes) {
        statusItem.button?.appearsDisabled = isStatusItemDisabled
      }
    }
  }

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    migrateUserDefaults()
    disableUnusedGlobalHotkeys()

    // Initialize ContentManager and register sources
    let contentManager = ContentManager.shared
    
    // Register clipboard source
    contentManager.registerSource(ClipboardSource())
    
    // Register Prompts source
    registerPromptsSource()
    
    // Restore folder sources from bookmarks
    for url in Bookmarks.resolveAll() {
      let source = FileSystemSource(folderURL: url)
      contentManager.registerSource(source)
      Task {
        await source.refresh()
        source.startMonitoring()
      }
    }

    panel = FloatingPanel(
      contentRect: NSRect(origin: .zero, size: Defaults[.windowSize]),
      identifier: Bundle.main.bundleIdentifier ?? "org.conmeara.nozzle",
      statusBarButton: statusItem.button
    ) {
      ContentView()
    }
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    panel.toggle(height: AppState.shared.popup.height)
    return true
  }

  func applicationWillTerminate(_ notification: Notification) {
    if Defaults[.clearOnQuit] {
      AppState.shared.history.clear()
    }
    
    // Stop monitoring all folder sources
    let contentManager = ContentManager.shared
    for source in contentManager.getAllSources() {
      if let fileSource = source as? FileSystemSource {
        fileSource.stopMonitoring()
      }
    }
  }

  @MainActor
  private func registerPromptsSource() {
    // Resolve or create default folder
    let folderURL: URL = {
      if let data = Defaults[.promptsFolderBookmark] {
        var isStale = false
        if let url = try? URL(resolvingBookmarkData: data,
                              options: [.withSecurityScope],
                              relativeTo: nil,
                              bookmarkDataIsStale: &isStale),
           !isStale {
          _ = url.startAccessingSecurityScopedResource()
          return url
        }
      }
      
      let def = PromptsSource.defaultFolder()
      // Store bookmark so it persists
      if let bd = try? def.bookmarkData(options: [.withSecurityScope],
                                        includingResourceValuesForKeys: nil,
                                        relativeTo: nil) {
        Defaults[.promptsFolderBookmark] = bd
        Defaults[.promptsFolderPath] = def.path
      }
      _ = def.startAccessingSecurityScopedResource()
      return def
    }()

    let prompts = PromptsSource(folderURL: folderURL)
    ContentManager.shared.registerSource(prompts)
    prompts.startMonitoring()
  }

  private func migrateUserDefaults() {
    if Defaults[.migrations]["2024-07-01-version-2"] != true {
      // Start 2.x from scratch.
      Defaults.reset(.migrations)

      // Inverse hide* configuration keys.
      Defaults[.showFooter] = !UserDefaults.standard.bool(forKey: "hideFooter")
      Defaults[.showSearch] = !UserDefaults.standard.bool(forKey: "hideSearch")
      Defaults[.showTitle] = !UserDefaults.standard.bool(forKey: "hideTitle")
      UserDefaults.standard.removeObject(forKey: "hideFooter")
      UserDefaults.standard.removeObject(forKey: "hideSearch")
      UserDefaults.standard.removeObject(forKey: "hideTitle")

      Defaults[.migrations]["2024-07-01-version-2"] = true
    }

    // The following defaults are not used in nozzle 2.x
    // and should be removed in 3.x.
    // - LaunchAtLogin__hasMigrated
    // - avoidTakingFocus
    // - saratovSeparator
    // - maxMenuItemLength
    // - maxMenuItems
  }

  @objc
  private func performStatusItemClick() {
    if let event = NSApp.currentEvent {
      let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

      if modifierFlags.contains(.option) {
        Defaults[.ignoreEvents].toggle()

        if modifierFlags.contains(.shift) {
          Defaults[.ignoreOnlyNextEvent] = Defaults[.ignoreEvents]
        }

        return
      }

      if event.type == .rightMouseUp {
        showContextMenu()
        return
      }
    }

    panel.toggle(height: AppState.shared.popup.height, at: .statusItem)
  }

  private func showContextMenu() {
    // Close the main app window to avoid glass-on-glass effect
    panel.close()
    
    let menu = NSMenu()
    
    let preferencesItem = NSMenuItem(
      title: NSLocalizedString("preferences", comment: ""),
      action: #selector(openPreferencesFromMenu),
      keyEquivalent: ","
    )
    preferencesItem.target = self
    menu.addItem(preferencesItem)
    
    // Debug menu item
    #if DEBUG
    menu.addItem(NSMenuItem.separator())
    
    let debugItem = NSMenuItem(
      title: "🎤 Test Dictation Crash Scenarios",
      action: #selector(testDictationCrash),
      keyEquivalent: ""
    )
    debugItem.target = self
    menu.addItem(debugItem)
    #endif
    
    menu.addItem(NSMenuItem.separator())
    
    let quitItem = NSMenuItem(
      title: NSLocalizedString("quit", comment: ""),
      action: #selector(quitFromMenu),
      keyEquivalent: "q"
    )
    quitItem.target = self
    menu.addItem(quitItem)
    
    statusItem.menu = menu
    statusItem.button?.performClick(nil)
    statusItem.menu = nil
  }

  @objc
  private func openPreferencesFromMenu() {
    AppState.shared.openPreferences()
  }

  @objc
  private func quitFromMenu() {
    AppState.shared.quit()
  }
  
  @objc
  private func testDictationCrash() {
    Task {
      await DictationManager.shared.testCrashScenarios()
    }
  }

  private func synchronizeMenuIconText() {
    _ = withObservationTracking {
      AppState.shared.menuIconText
    } onChange: {
      DispatchQueue.main.async {
        if Defaults[.showRecentCopyInMenuBar] {
          self.statusItem.button?.title = AppState.shared.menuIconText
        }
        self.synchronizeMenuIconText()
      }
    }
  }

  private func disableUnusedGlobalHotkeys() {
    let names: [KeyboardShortcuts.Name] = [.delete, .pin]
    KeyboardShortcuts.disable(names)

    NotificationCenter.default.addObserver(
      forName: Notification.Name("KeyboardShortcuts_shortcutByNameDidChange"),
      object: nil,
      queue: nil
    ) { notification in
      if let name = notification.userInfo?["name"] as? KeyboardShortcuts.Name, names.contains(name) {
        KeyboardShortcuts.disable(name)
      }
    }
  }
}
