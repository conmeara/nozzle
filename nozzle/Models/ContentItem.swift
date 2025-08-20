import AppKit
import Foundation

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
        self.isSelected = isSelected
        self.isVisible = isVisible
    }
}