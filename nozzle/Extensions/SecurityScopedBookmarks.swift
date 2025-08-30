import Foundation
import AppKit

enum Bookmarks {
    private static let bookmarksKey = "nozzle.folder.bookmarks"
    
    static func store(url: URL) throws {
        let bookmarkData = try url.bookmarkData(
            options: [.withSecurityScope],  // Remove read-only restriction for editing
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        
        var bookmarks = UserDefaults.standard.object(forKey: bookmarksKey) as? [String: Data] ?? [:]
        // Canonicalize key to avoid path representation drift
        let keyPath = url.standardizedFileURL.path
        bookmarks[keyPath] = bookmarkData
        UserDefaults.standard.set(bookmarks, forKey: bookmarksKey)
        // Ensure persistence before potential app quit
        UserDefaults.standard.synchronize()
    }
    
    static func resolveAll() -> [URL] {
        guard let bookmarks = UserDefaults.standard.object(forKey: bookmarksKey) as? [String: Data] else {
            return []
        }
        
        return bookmarks.compactMap { _, data in
            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else { return nil }
            
            if !isStale && url.startAccessingSecurityScopedResource() {
                return url
            }
            return nil
        }
    }
    
    // Check if a URL has write access through security-scoped bookmarks
    static func hasWriteAccess(for url: URL) -> Bool {
        let parentURL = url.deletingLastPathComponent()
        return parentURL.startAccessingSecurityScopedResource()
    }
    
    static func remove(url: URL) {
        var bookmarks = UserDefaults.standard.object(forKey: bookmarksKey) as? [String: Data] ?? [:]
        if bookmarks.isEmpty { return }

        let targetStdPath = url.standardizedFileURL.path
        let targetIdentity = FileIdentity.snapshot(for: url).identity

        var keysToRemove: [String] = []
        for (keyPath, data) in bookmarks {
            // Quick path match on canonicalized path
            if keyPath == targetStdPath {
                keysToRemove.append(keyPath)
                continue
            }
            // Resolve bookmark and compare by identity/path to be robust
            var isStale = false
            if let resolved = try? URL(resolvingBookmarkData: data,
                                       options: [.withSecurityScope],
                                       relativeTo: nil,
                                       bookmarkDataIsStale: &isStale) {
                let resolvedStdPath = resolved.standardizedFileURL.path
                if resolvedStdPath == targetStdPath {
                    keysToRemove.append(keyPath)
                    continue
                }
                if let t = targetIdentity {
                    let resolvedId = FileIdentity.snapshot(for: resolved).identity
                    if resolvedId == t {
                        keysToRemove.append(keyPath)
                        continue
                    }
                }
            }
        }

        if !keysToRemove.isEmpty {
            for key in keysToRemove { bookmarks.removeValue(forKey: key) }
            UserDefaults.standard.set(bookmarks, forKey: bookmarksKey)
            UserDefaults.standard.synchronize()
        }
    }
}
