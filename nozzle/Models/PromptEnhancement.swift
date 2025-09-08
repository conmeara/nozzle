import Foundation

/// Model representing an enhanced prompt result
struct EnhancedPrompt: Codable, Sendable {
    /// The improved prompt text
    let improvedPrompt: String
    
    /// Brief list of improvements made (optional, for future use)
    let changesMade: [String]?
    
    /// Timestamp of when the enhancement was performed
    let enhancedAt: Date
    
    init(improvedPrompt: String, changesMade: [String]? = nil) {
        self.improvedPrompt = improvedPrompt
        self.changesMade = changesMade
        self.enhancedAt = Date()
    }
}

/// Extension to track enhancement history if needed in the future
extension EnhancedPrompt: Identifiable {
    var id: Date { enhancedAt }
}