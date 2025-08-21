import Foundation
import CoreServices

/// Get the current FSEvents event ID
func FSEventStreamGetCurrentEventId() -> FSEventStreamEventId {
    return FSEventsGetCurrentEventId()
}

/// Swift wrapper around FSEvents for monitoring file system changes
final class FSEventsStream {
    struct Config {
        let root: URL
        let sinceWhen: FSEventStreamEventId
        let latency: CFTimeInterval
        let flags: FSEventStreamCreateFlags
        let excludePaths: [String]
        let queue: DispatchQueue
    }
    
    struct Event {
        let path: String
        let id: FSEventStreamEventId
        let flags: FSEventStreamEventFlags
    }
    
    private var stream: FSEventStreamRef?
    private let config: Config
    private let handler: ([Event]) -> Void
    
    init(config: Config, handler: @escaping ([Event]) -> Void) {
        self.config = config
        self.handler = handler
    }
    
    func start() {
        guard stream == nil else { return }
        
        // Validate that the root path exists and is accessible
        guard config.root.hasDirectoryPath,
              FileManager.default.fileExists(atPath: config.root.path) else {
            print("FSEventsStream: Root path does not exist or is not accessible: \(config.root.path)")
            return
        }
        
        // Create the stream
        let pathsToWatch = [config.root.path] as CFArray
        
        // Create context for the callback
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        
        stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { (streamRef, clientCallbackInfo, numEvents, eventPaths, eventFlags, eventIds) in
                // Extract self from context safely
                guard let info = clientCallbackInfo,
                      numEvents > 0 else { return }
                
                let stream = Unmanaged<FSEventsStream>.fromOpaque(info).takeUnretainedValue()
                
                // Convert the paths CFArray to Swift array
                let pathsArray = unsafeBitCast(eventPaths, to: NSArray.self) as! [String]
                let flagsBuffer = UnsafeBufferPointer(start: eventFlags, count: Int(numEvents))
                let idsBuffer = UnsafeBufferPointer(start: eventIds, count: Int(numEvents))
                
                var events: [Event] = []
                events.reserveCapacity(Int(numEvents))
                
                for i in 0..<Int(numEvents) {
                    // Bounds checking
                    guard i < pathsArray.count,
                          i < flagsBuffer.count,
                          i < idsBuffer.count else { 
                        continue 
                    }
                    
                    let path = pathsArray[i]
                    
                    events.append(Event(
                        path: path,
                        id: idsBuffer[i],
                        flags: flagsBuffer[i]
                    ))
                }
                
                // Only call handler if we have valid events
                guard !events.isEmpty else { return }
                
                // Call handler directly - the handler will dispatch to its queue
                stream.handler(events)
            },
            &context,
            pathsToWatch,
            config.sinceWhen,
            config.latency,
            config.flags
        )
        
        guard let stream = stream else { return }
        
        // Set exclusion paths if provided
        if !config.excludePaths.isEmpty {
            FSEventStreamSetExclusionPaths(stream, config.excludePaths as CFArray)
        }
        
        // Schedule on the dispatch queue
        FSEventStreamSetDispatchQueue(stream, config.queue)
        
        // Start the stream
        FSEventStreamStart(stream)
    }
    
    func stop() {
        guard let stream = stream else { return }
        
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        
        self.stream = nil
    }
    
    deinit {
        stop()
    }
}

// MARK: - Event Flag Helpers

extension FSEventsStream {
    static func isItemCreated(_ flags: FSEventStreamEventFlags) -> Bool {
        return (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated)) != 0
    }
    
    static func isItemRemoved(_ flags: FSEventStreamEventFlags) -> Bool {
        return (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved)) != 0
    }
    
    static func isItemRenamed(_ flags: FSEventStreamEventFlags) -> Bool {
        return (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed)) != 0
    }
    
    static func isItemModified(_ flags: FSEventStreamEventFlags) -> Bool {
        return (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified)) != 0
    }
    
    static func isItemInodeMetaMod(_ flags: FSEventStreamEventFlags) -> Bool {
        return (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemInodeMetaMod)) != 0
    }
    
    static func isItemIsFile(_ flags: FSEventStreamEventFlags) -> Bool {
        return (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsFile)) != 0
    }
    
    static func isItemIsDir(_ flags: FSEventStreamEventFlags) -> Bool {
        return (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsDir)) != 0
    }
    
    static func mustScanSubDirs(_ flags: FSEventStreamEventFlags) -> Bool {
        return (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagMustScanSubDirs)) != 0
    }
    
    static func userDropped(_ flags: FSEventStreamEventFlags) -> Bool {
        return (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagUserDropped)) != 0
    }
    
    static func kernelDropped(_ flags: FSEventStreamEventFlags) -> Bool {
        return (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagKernelDropped)) != 0
    }
    
    static func rootChanged(_ flags: FSEventStreamEventFlags) -> Bool {
        return (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagRootChanged)) != 0
    }
}