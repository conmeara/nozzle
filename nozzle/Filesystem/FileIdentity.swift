import Foundation

/// Helper for fetching stable file identities and metadata
enum FileIdentity {
    struct Snapshot {
        let identity: Data?    // fileResourceIdentifierKey - stable across renames on APFS
        let modDate: Date
        let isDirectory: Bool
        let size: Int64?
    }
    
    /// Fetch a snapshot of file metadata including stable identity
    static func snapshot(for url: URL) -> Snapshot {
        let keys: Set<URLResourceKey> = [
            .fileResourceIdentifierKey,
            .contentModificationDateKey,
            .isDirectoryKey,
            .fileSizeKey
        ]
        
        let resourceValues = try? url.resourceValues(forKeys: keys)
        
        return Snapshot(
            identity: resourceValues?.fileResourceIdentifier as? Data,
            modDate: resourceValues?.contentModificationDate ?? .distantPast,
            isDirectory: resourceValues?.isDirectory ?? false,
            size: resourceValues?.fileSize.map { Int64($0) }
        )
    }
    
    /// Check if a file exists at the given path
    static func exists(at path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }
    
    /// Check if a URL points to a directory
    static func isDirectory(at url: URL) -> Bool {
        let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey])
        return resourceValues?.isDirectory ?? false
    }
}