import Foundation
import Observation

@Observable @MainActor
final class FolderExpansionState {
    private var expandedPaths: Set<String> = []
    private let maxDepth: Int = 3
    private let sourceId: String
    
    init(sourceId: String) {
        self.sourceId = sourceId
        loadPersistedState()
    }
    
    func isExpanded(_ path: String) -> Bool {
        expandedPaths.contains(path)
    }
    
    func toggleExpansion(_ path: String) {
        if expandedPaths.contains(path) {
            expandedPaths.remove(path)
        } else {
            expandedPaths.insert(path)
        }
        persistState()
    }
    
    func setExpanded(_ path: String, expanded: Bool) {
        if expanded {
            expandedPaths.insert(path)
        } else {
            expandedPaths.remove(path)
        }
        persistState()
    }
    
    func canExpand(depth: Int) -> Bool {
        return depth < maxDepth
    }
    
    func getAllExpandedPaths() -> Set<String> {
        return expandedPaths
    }
    
    private func persistState() {
        let key = "FolderExpansion.\(sourceId)"
        let pathsArray = Array(expandedPaths)
        UserDefaults.standard.set(pathsArray, forKey: key)
    }
    
    private func loadPersistedState() {
        let key = "FolderExpansion.\(sourceId)"
        if let pathsArray = UserDefaults.standard.array(forKey: key) as? [String] {
            expandedPaths = Set(pathsArray)
        }
    }
}