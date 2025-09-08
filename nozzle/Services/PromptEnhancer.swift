import Foundation
import FoundationModels

enum EnhancementError: LocalizedError {
    case notAvailable
    case emptyPrompt
    case modelError(String)
    case contextWindowExceeded
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "AI enhancement requires Apple Intelligence to be enabled in System Settings"
        case .emptyPrompt:
            return "Please enter some text to enhance"
        case .modelError(let message):
            return "Enhancement failed: \(message)"
        case .contextWindowExceeded:
            return "The prompt is too long to enhance. Please shorten it and try again"
        }
    }
}

@MainActor
class PromptEnhancer: ObservableObject {
    static let shared = PromptEnhancer()
    
    @Published var isEnhancing = false
    @Published var lastError: Error?
    
    private init() {}
    
    /// Check if the Foundation Models framework is available on this device
    func isAvailable() -> Bool {
        // Check if the system language model is available
        // This requires Apple Intelligence to be enabled
        // SystemLanguageModel.default will be available if the device supports it
        // We'll check by attempting to create a session during actual use
        return true  // We'll handle actual availability during enhance() call
    }
    
    /// Enhance a prompt using Apple's on-device language model
    func enhance(_ prompt: String) async throws -> String {
        // Validate input
        let trimmedPrompt = prompt.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            throw EnhancementError.emptyPrompt
        }
        
        // Update state
        isEnhancing = true
        defer { 
            Task { @MainActor in
                isEnhancing = false 
            }
        }
        
        do {
            // Check availability by attempting to access the system model
            _ = SystemLanguageModel.default
            
            // Create a session with instructions for prompt enhancement
            let session = LanguageModelSession(
                instructions: Instructions {
                    """
                    You are an expert at improving instruction prompts. Your task is to enhance 
                    the given prompt to be clearer, more specific, and more effective.
                    
                    Rules:
                    1. Keep the core intent completely unchanged - do not alter what the user is asking for
                    2. Make instructions clear, specific, and unambiguous
                    3. Improve structure and logical flow
                    4. Fix any grammar, spelling, or clarity issues
                    5. Keep it concise - don't make it unnecessarily longer
                    6. Use active voice when possible
                    7. Break complex instructions into clear steps if needed
                    
                    IMPORTANT: Do NOT add examples, context, or background information. 
                    Only enhance the instructional text itself. The user will add context 
                    and examples separately through the application.
                    
                    Return ONLY the improved prompt text, nothing else. No explanations, 
                    no metadata, just the enhanced prompt.
                    """
                }
            )
            
            // Configure generation options for balanced enhancement
            let options = GenerationOptions(
                temperature: 0.7  // Balanced between creativity and consistency
            )
            
            // Get the enhanced prompt
            let response = try await session.respond(
                to: trimmedPrompt,
                options: options
            )
            
            // Clean up and return the enhanced text
            let enhancedText = response.content.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            // Ensure we got meaningful output
            guard !enhancedText.isEmpty else {
                throw EnhancementError.modelError("No enhancement generated")
            }
            
            return enhancedText
            
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize(_) {
            // Handle context window exceeded error
            lastError = EnhancementError.contextWindowExceeded
            throw EnhancementError.contextWindowExceeded
        } catch {
            // Check if this is a model availability error
            let errorMessage = error.localizedDescription
            if errorMessage.contains("not available") || errorMessage.contains("Apple Intelligence") {
                lastError = EnhancementError.notAvailable
                throw EnhancementError.notAvailable
            } else {
                // Handle other errors
                lastError = EnhancementError.modelError(errorMessage)
                throw EnhancementError.modelError(errorMessage)
            }
        }
    }
    
    /// Clear the last error
    func clearError() {
        lastError = nil
    }
}