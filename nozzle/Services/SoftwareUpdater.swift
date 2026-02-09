import Foundation
import Sparkle

/// @Observable wrapper around SPUUpdater for SwiftUI integration.
/// Provides automatic update checking and manual update triggers.
@Observable @MainActor
final class SoftwareUpdater {
    /// Whether the updater automatically checks for updates.
    var automaticallyChecksForUpdates: Bool = false {
        didSet {
            guard automaticallyChecksForUpdates != oldValue else { return }
            updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        }
    }

    /// Whether an update check can be performed right now.
    var canCheckForUpdates: Bool = false

    /// Shared singleton instance.
    static let shared = SoftwareUpdater()

    private let updaterDelegate = SparkleUpdaterDelegate()
    private let updaterController: SPUStandardUpdaterController
    private var updater: SPUUpdater { updaterController.updater }

    @ObservationIgnored
    private var automaticallyChecksForUpdatesObservation: NSKeyValueObservation?

    @ObservationIgnored
    private var canCheckForUpdatesObservation: NSKeyValueObservation?

    @ObservationIgnored
    private var pendingManualUpdateCheck = false

    private init() {
        // Initialize the updater controller with default settings
        // startingUpdater: true - starts the updater automatically
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: updaterDelegate,
            userDriverDelegate: nil
        )

        // Observe changes to automaticallyChecksForUpdates
        automaticallyChecksForUpdatesObservation = updater.observe(
            \.automaticallyChecksForUpdates,
            options: [.initial, .new, .old]
        ) { [weak self] _, change in
            guard change.newValue != change.oldValue else { return }
            let newValue = change.newValue ?? false
            Task { @MainActor [weak self] in
                self?.automaticallyChecksForUpdates = newValue
            }
        }

        // Observe changes to canCheckForUpdates
        canCheckForUpdatesObservation = updater.observe(
            \.canCheckForUpdates,
            options: [.initial, .new]
        ) { [weak self] _, change in
            let newValue = change.newValue ?? false
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.canCheckForUpdates = newValue

                // If user requested an update check before Sparkle was ready,
                // run it as soon as canCheckForUpdates flips to true.
                if newValue, self.pendingManualUpdateCheck {
                    self.pendingManualUpdateCheck = false
                    self.updater.checkForUpdates()
                }
            }
        }
    }

    /// Manually trigger an update check.
    func checkForUpdates() {
        guard updater.canCheckForUpdates else {
            pendingManualUpdateCheck = true
            return
        }

        pendingManualUpdateCheck = false
        updater.checkForUpdates()
    }
}
