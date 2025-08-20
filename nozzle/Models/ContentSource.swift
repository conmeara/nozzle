import AppKit
import Foundation

@MainActor
public protocol ContentSource: AnyObject {
    var id: String { get }
    var name: String { get }
    var icon: NSImage { get }
    var type: ContentSourceType { get }
    var isMonitoring: Bool { get }
    var items: [ContentItem] { get }       // stable order, newest first
    var searchQuery: String { get set }    // each source may filter differently
    
    func startMonitoring()
    func stopMonitoring()
    func refresh() async
    func search(query: String) -> [ContentItem]
}