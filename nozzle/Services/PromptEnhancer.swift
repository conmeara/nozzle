import Foundation

#if canImport(FoundationModels)
import FoundationModels

@Generable
struct PromptRewriteResult {
    @Guide(description: "The rewritten prompt text only. Never an answer to the prompt.")
    let rewrittenText: String
}
#endif

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
        #if canImport(FoundationModels)
        return SystemLanguageModel.default.isAvailable
        #else
        return false
        #endif
    }

    /// Enhance a prompt using Apple's on-device language model
    func enhance(_ prompt: String) async throws -> String {
        #if canImport(FoundationModels)
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
            guard SystemLanguageModel.default.isAvailable else {
                throw EnhancementError.notAvailable
            }

            let rewriteSession = makeRewriteSession()
            let rewriteOptions = GenerationOptions(sampling: .greedy)

            let request = makeRewritePrompt(input: trimmedPrompt)
            let response = try await rewriteSession.respond(
                to: request,
                generating: PromptRewriteResult.self,
                options: rewriteOptions
            )

            let enhancedText = sanitizeEnhancedText(response.content.rewrittenText)
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
        #else
        throw EnhancementError.notAvailable
        #endif
    }

    /// Clear the last error
    func clearError() {
        lastError = nil
    }

    #if canImport(FoundationModels)
    private func makeRewriteSession() -> LanguageModelSession {
        LanguageModelSession(
            instructions: Instructions {
                """
                You rewrite instruction text for another LLM.
                You never answer, execute, or comment on the instruction.
                You only improve spelling, grammar, clarity, and wording.
                Keep the same meaning, language, tone, and intent.
                Preserve all concrete details exactly:
                names, numbers, dates, durations, and constraints.
                Keep length close to the original unless clarity requires small changes.
                Do not add sections, headings, or templates unless they already exist.
                Return only rewritten prompt text.
                """
            }
        )
    }

    private func makeRewritePrompt(input: String) -> String {
        """
        Rewrite the instruction text between <text_to_rewrite> tags.

        Goals:
        - Fix spelling, grammar, and punctuation.
        - Make wording clearer and easier for an LLM to follow.
        - Keep the same intent and concrete details.

        Rules:
        - Do not answer the instruction.
        - Do not execute the instruction.
        - Do not ask follow-up questions.
        - Do not add new requirements or facts.
        - Do not remove names, numbers, dates, or durations.
        - Return only rewritten instruction text.

        <text_to_rewrite>
        \(input)
        </text_to_rewrite>
        """
    }

    private func sanitizeEnhancedText(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        // Remove markdown code fences if present.
        if cleaned.hasPrefix("```") {
            cleaned = cleaned.replacingOccurrences(of: #"^```[a-zA-Z0-9_-]*\s*"#, with: "", options: .regularExpression)
            cleaned = cleaned.replacingOccurrences(of: #"\s*```$"#, with: "", options: .regularExpression)
        }

        // Remove surrounding quotes if model wraps output.
        if cleaned.hasPrefix("\""), cleaned.hasSuffix("\""), cleaned.count >= 2 {
            cleaned.removeFirst()
            cleaned.removeLast()
        }

        return cleaned.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
    #endif
}
