import AppKit
import Foundation
import UniformTypeIdentifiers

public struct ContentItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let title: String
    public let timestamp: Date
    public let sourceType: ContentSourceType
    public let sourceId: String
    
    // Optional format-specific data (future-safe)
    public let fileURL: URL?
    public let imageData: Data?
    public let rtfData: Data?
    public let htmlData: Data?
    public let plainText: String?
    
    // File identity for stable tracking across renames (FSEvents)
    public let fileIdentity: Data?
    
    // File metadata
    public let uniformTypeIdentifier: String?
    public let fileSize: Int64?
    
    // Hierarchical folder support
    public let isFolder: Bool
    public let depth: Int
    public let parentPath: String?
    
    // UI state (kept here so Universal views don't mutate external state)
    public var isSelected: Bool = false
    public var isVisible: Bool = true
    
    public init(
        id: UUID,
        title: String,
        timestamp: Date,
        sourceType: ContentSourceType,
        sourceId: String,
        fileURL: URL? = nil,
        imageData: Data? = nil,
        rtfData: Data? = nil,
        htmlData: Data? = nil,
        plainText: String? = nil,
        fileIdentity: Data? = nil,
        uniformTypeIdentifier: String? = nil,
        fileSize: Int64? = nil,
        isFolder: Bool = false,
        depth: Int = 0,
        parentPath: String? = nil,
        isSelected: Bool = false,
        isVisible: Bool = true
    ) {
        self.id = id
        self.title = title
        self.timestamp = timestamp
        self.sourceType = sourceType
        self.sourceId = sourceId
        self.fileURL = fileURL
        self.imageData = imageData
        self.rtfData = rtfData
        self.htmlData = htmlData
        self.plainText = plainText
        self.fileIdentity = fileIdentity
        self.uniformTypeIdentifier = uniformTypeIdentifier
        self.fileSize = fileSize
        self.isFolder = isFolder
        self.depth = depth
        self.parentPath = parentPath
        self.isSelected = isSelected
        self.isVisible = isVisible
    }
}

// MARK: - UTType Helpers
extension ContentItem {
    var fileUTType: UTType? {
        uniformTypeIdentifier.flatMap(UTType.init)
    }
    
    var isImage: Bool {
        fileUTType?.conforms(to: .image) == true
    }
    
    var isText: Bool {
        fileUTType?.conforms(to: .text) == true
    }
    
    var isRTF: Bool {
        fileUTType == .rtf || fileUTType == .rtfd
    }
    
    var isMarkdown: Bool {
        fileUTType?.identifier == "net.daringfireball.markdown" ||
        fileUTType?.identifier == "public.markdown" ||
        fileUTType?.preferredFilenameExtension == "md"
    }
    
    var isPlainText: Bool {
        fileUTType == .plainText || fileUTType == .utf8PlainText || fileUTType == .utf16PlainText
    }
}