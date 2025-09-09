import Foundation

enum ScreenshotSourceHeuristics {
    /// Best-effort guess of the originating app bundle identifier for a clipboard image URL.
    /// Uses path fingerprints of popular tools; returns nil if no match.
    static func guessBundleId(for url: URL) -> String? {
        let path = url.path.lowercased()

        // CleanShot X
        if path.contains("/library/application support/cleanshot/") ||
            path.contains("/cleanshot ") ||
            path.contains("/cleanshot/") {
            return "pl.maketheweb.cleanshotx"
        }

        // Shottr (common paths under Pictures/Shottr or Application Support/Shottr)
        if path.contains("/pictures/shottr/") ||
            path.contains("/library/application support/shottr/") ||
            path.contains("/shottr ") ||
            path.contains("/shottr/") {
            return "com.TIGERBEBE.Shottr"
        }

        // Xnapper (sandbox container path or support dir may contain Xnapper)
        if path.contains("/xnapper/") ||
            path.contains("org.xnapper.xnapper") ||
            path.contains("/library/containers/org.xnapper.xnapper/") ||
            path.contains("/library/application support/xnapper/") {
            return "org.xnapper.Xnapper"
        }

        // Monosnap
        if path.contains("/monosnap/") || path.contains("com.monosnap.monosnap") {
            return "com.monosnap.monosnap"
        }

        // Default: no guess
        return nil
    }
}

