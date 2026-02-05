import Foundation
import OSLog
import Sparkle

@MainActor
final class SparkleUpdaterDelegate: NSObject, SPUUpdaterDelegate {
    private let logger = Logger(subsystem: "org.conmeara.nozzle.updater", category: "Sparkle")

    func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        logError(error, context: "Update aborted")
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        guard let error else { return }
        logError(error, context: "Update cycle finished with error")
    }

    private func logError(_ error: Error, context: String) {
        let nsError = error as NSError
        let userInfo = String(describing: nsError.userInfo)
        logger.error("\(context, privacy: .public): \(nsError.domain, privacy: .public) (\(nsError.code)) - \(nsError.localizedDescription, privacy: .public) | userInfo=\(userInfo, privacy: .public)")
    }
}
