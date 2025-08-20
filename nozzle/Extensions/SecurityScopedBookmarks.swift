import Foundation
import AppKit

enum Bookmarks {
    private static let bookmarksKey = "nozzle.folder.bookmarks"
    
    static func store(url: URL) throws {
        let bookmarkData = try url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        
        var bookmarks = UserDefaults.standard.object(forKey: bookmarksKey) as? [String: Data] ?? [:]
        bookmarks[url.path] = bookmarkData
        UserDefaults.standard.set(bookmarks, forKey: bookmarksKey)
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
    
    static func remove(url: URL) {
        var bookmarks = UserDefaults.standard.object(forKey: bookmarksKey) as? [String: Data] ?? [:]
        bookmarks.removeValue(forKey: url.path)
        UserDefaults.standard.set(bookmarks, forKey: bookmarksKey)
    }
}