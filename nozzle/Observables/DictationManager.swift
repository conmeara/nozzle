import Foundation
@preconcurrency import Speech
@preconcurrency import AVFoundation
import SwiftUI

@Observable
final class DictationManager {
    static let shared = DictationManager()
    
    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    // Keep a single engine instance like the sample; never set to nil.
    // nonisolated to allow audio callbacks on realtime thread
    nonisolated private let audioEngine = AVAudioEngine()
    private var inputSequence: AsyncStream<AnalyzerInput>?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var recognitionTask: Task<Void, Error>?
    private let bufferConverter = BufferConverter()
    private var audioStreamContinuation: AsyncStream<AVAudioPCMBuffer>.Continuation?
    
    // Debug tracking
    private var debugSessionId: UUID?
    private let debugQueue = DispatchQueue(label: "DictationManager.Debug", qos: .utility)
    private var isCleaningUp: Bool = false
    
    var isRecording = false
    // Match sample: keep attributed transcripts for styling and timing
    var volatileTranscript: AttributedString = ""
    var finalizedTranscript: AttributedString = ""
    
    // Optional: expose download progress similar to sample
    var downloadProgress: Progress?
    
    private var targetTextBinding: Binding<String>?
    private var analyzerFormat: AVAudioFormat?
    // Streaming task so we don't block the main actor
    private var audioStreamTask: Task<Void, Never>?
    
    init() {} // engine created above
    
    // MARK: - Debug Logging
    
    private func debugLog(_ message: String, function: String = #function, line: Int = #line) {
        let sessionId = debugSessionId?.uuidString.prefix(8) ?? "no-session"
        
        // Safe queue label extraction
        let queueLabel: String
        if let label = String(cString: __dispatch_queue_get_label(nil), encoding: .utf8), !label.isEmpty {
            queueLabel = label
        } else {
            queueLabel = "unknown"
        }
        
        let threadId = Thread.current.isMainThread ? "main" : "bg"
        let timestamp = Date().timeIntervalSince1970
        
        // Use async logging to avoid queue issues
        debugQueue.async {
            print("🎤 [\(sessionId)] [\(String(format: "%.3f", timestamp))] \(function):\(line) [\(threadId)|\(queueLabel)] \(message)")
        }
    }
    
    @MainActor
    func toggleDictation(for textBinding: Binding<String>) async {
        debugLog("toggleDictation called, isRecording: \(isRecording)")
        
        if isRecording {
            await stopDictation()
        } else {
            await startDictation(for: textBinding)
        }
    }
    
    @MainActor
    private func startDictation(for textBinding: Binding<String>) async {
        debugSessionId = UUID()
        debugLog("Starting dictation session")
        
        guard await requestMicrophonePermission() else {
            debugLog("Microphone permission denied")
            return
        }
        
        targetTextBinding = textBinding
        finalizedTranscript = ""
        volatileTranscript = ""
        
        // Play system sound for start recording
        NSSound.beep()
        
        isRecording = true
        debugLog("Set isRecording = true")
        
        do {
            try await setupTranscriber()
            debugLog("Transcriber setup completed")
            
            // Start audio streaming on a detached task; don't await here
            audioStreamTask = Task.detached(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                do {
                    try await self.startAudioStream()
                } catch {
                    // Hop to main for logging to avoid cross-actor diagnostics
                    await MainActor.run { self.debugLog("Audio streaming error: \(error)") }
                }
            }
        
        } catch {
            debugLog("Failed to start dictation: \(error)")
            isRecording = false
        }
    }
    
    @MainActor
    private func stopDictation() async {
        debugLog("Stopping dictation session")
        isCleaningUp = true
        isRecording = false
        
        // Play system sound for stop recording
        NSSound.beep()
        
        // Clean shutdown sequence - follow proper order
        debugLog("Starting cleanup sequence")
        
        // 0. Cancel streaming task if running
        audioStreamTask?.cancel()
        audioStreamTask = nil

        // 1. Stop audio engine
        debugLog("Stopping audio engine")
        audioEngine.stop()
        
        // 2. Clear continuation to stop yielding buffers
        debugLog("Clearing audio stream continuation")
        audioStreamContinuation?.finish()
        audioStreamContinuation = nil
        
        // 3. Add small delay for audio thread cleanup
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // 4. Remove tap safely
        debugLog("Removing audio tap")
        audioEngine.inputNode.removeTap(onBus: 0)
        debugLog("Audio tap removed successfully")
        
        // 5. No file to clear; keep the engine instance (sample behavior)
        
        // Finish analyzer input
        debugLog("Finishing input builder")
        inputBuilder?.finish()
        inputBuilder = nil
        
        // 6. Wait for analyzer to finish
        if let analyzer = analyzer {
            debugLog("Finalizing analyzer")
            try? await analyzer.finalizeAndFinishThroughEndOfInput()
        }
        
        // 7. Cancel recognition task
        debugLog("Cancelling recognition task")
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Update text binding with finalized transcript
        if !finalizedTranscript.characters.isEmpty, let binding = targetTextBinding {
            let currentText = binding.wrappedValue
            let separator = currentText.isEmpty ? "" : " "
            binding.wrappedValue = currentText + separator + String(finalizedTranscript.characters)
            debugLog("Updated text binding with finalized transcript")
        }
        
        // Clean up
        targetTextBinding = nil
        finalizedTranscript = ""
        volatileTranscript = ""
        transcriber = nil
        analyzer = nil
        isCleaningUp = false
        debugLog("Dictation session cleanup completed")
    }
    
    @MainActor
    private func setupTranscriber() async throws {
        let chosenLocale = await Self.chooseSupportedLocale(from: Locale.current)
        
        transcriber = SpeechTranscriber(
            locale: chosenLocale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange]
        )
        
        guard let transcriber = transcriber else {
            throw DictationError.failedToSetupTranscriber
        }
        
        try await ensureModelDownloaded(for: transcriber, locale: chosenLocale)
        
        analyzer = SpeechAnalyzer(modules: [transcriber])
        // Preheat analyzer resources to avoid late-loading hiccups
        try? await analyzer?.prepareToAnalyze(in: nil)
        analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        
        (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()
        
        guard let inputSequence = inputSequence else { return }
        
        recognitionTask = Task {
            do {
                for try await case let result in transcriber.results {
                    await MainActor.run {
                        let text = result.text
                        if result.isFinal {
                            finalizedTranscript += text
                            volatileTranscript = ""
                            updateTargetText()
                        } else {
                            var temp = text
                            temp.foregroundColor = .purple.opacity(0.4)
                            volatileTranscript = temp
                            updateTargetText()
                        }
                    }
                }
            } catch {
                print("Speech recognition failed: \(error)")
            }
        }
        
        try await analyzer?.start(inputSequence: inputSequence)
    }

    nonisolated private static func chooseSupportedLocale(from preferred: Locale) async -> Locale {
        // Prefer exact BCP-47 match; otherwise fall back to first supported locale
        let supported = await SpeechTranscriber.supportedLocales
        if supported.map({ $0.identifier(.bcp47) }).contains(preferred.identifier(.bcp47)) {
            return preferred
        }
        return supported.first ?? preferred
    }
    
    @MainActor
    private func updateTargetText() {
        guard let binding = targetTextBinding else { return }
        let currentText = binding.wrappedValue
        
        var baseText = currentText
        if !finalizedTranscript.characters.isEmpty {
            let separator = currentText.isEmpty ? "" : " "
            baseText = currentText + separator + String(finalizedTranscript.characters)
        }
        
        if !volatileTranscript.characters.isEmpty {
            let separator = baseText.isEmpty ? "" : " "
            binding.wrappedValue = baseText + separator + String(volatileTranscript.characters)
        } else {
            binding.wrappedValue = baseText
        }
    }
    
    // Not @MainActor - audio operations need to run on appropriate threads
    private func startAudioStream() async throws {
        debugLog("Setting up audio stream")
        
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .spokenAudio)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
        
        // Setup audio engine
        try setupAudioEngine()
        debugLog("Audio engine setup completed")
        
        // Create audio stream using the fixed pattern
        let audioStream = try audioStream()
        debugLog("Audio stream created and ready")
        
        // Process buffers as they arrive (no timeout, sample parity)
        for await buffer in audioStream {
            guard isRecording else { break }
            try await streamAudioToTranscriber(buffer)
        }
        debugLog("Audio stream processing completed")
    }
    
    private func setupAudioEngine() throws {
        debugLog("Setting up audio engine (sample parity)")
        let inputNode = audioEngine.inputNode
        
        // Remove any existing tap
        debugLog("Removing existing audio tap")
        inputNode.removeTap(onBus: 0)
        debugLog("Audio engine initialization completed")
    }
    
    private func audioStream() throws -> AsyncStream<AVAudioPCMBuffer> {
        debugLog("Setting up audio stream (Apple's exact pattern)")
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(
            onBus: 0,
            bufferSize: 4096,
            format: inputNode.outputFormat(forBus: 0)
        ) { [weak self] (buffer, time) in
            guard let self else { return }
            
            // DEBUG: Confirm tap callbacks are firing
            print("🔊 TAP CALLBACK! frames=\(buffer.frameLength)")
            
            // Yield buffer to continuation
            self.audioStreamContinuation?.yield(buffer)
        }
        
        debugLog("Audio tap installed")
        
        // Apple's exact sequence: prepare, start, THEN create stream
        audioEngine.prepare()
        try audioEngine.start()
        debugLog("Audio engine started")
        
        return AsyncStream(AVAudioPCMBuffer.self, bufferingPolicy: .unbounded) { continuation in
            self.audioStreamContinuation = continuation
        }
    }
    
    // Not on the main actor, like the sample's transcriber path
    private func streamAudioToTranscriber(_ buffer: AVAudioPCMBuffer) async throws {
        guard let inputBuilder = inputBuilder,
              let analyzerFormat = analyzerFormat else {
            debugLog("ERROR: Missing inputBuilder or analyzerFormat")
            throw DictationError.audioProcessingFailed
        }
        
        // debugLog("Converting buffer: frames=\(buffer.frameLength)") // Too verbose, only enable if needed
        
        do {
            let converted = try bufferConverter.convertBuffer(buffer, to: analyzerFormat)
            inputBuilder.yield(AnalyzerInput(buffer: converted))
        } catch {
            debugLog("ERROR: Buffer conversion failed: \(error)")
            throw error
        }
    }
    
    // Not @MainActor - permission checks can happen on any thread
    private func requestMicrophonePermission() async -> Bool {
        #if os(macOS)
        // On macOS, check authorization status (no device enumeration to avoid CMIO errors)
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        debugLog("Current microphone authorization status: \(currentStatus.rawValue)")
        
        switch currentStatus {
        case .authorized:
            debugLog("Microphone access already authorized")
            return true
        case .notDetermined:
            debugLog("Requesting microphone access")
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            debugLog("Microphone access granted: \(granted)")
            return granted
        case .denied, .restricted:
            debugLog("ERROR: Microphone access denied or restricted")
            return false
        @unknown default:
            debugLog("ERROR: Unknown microphone authorization status")
            return false
        }
        #else
        // iOS permission handling
        if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
            return true
        }
        return await AVCaptureDevice.requestAccess(for: .audio)
        #endif
    }
    
    @MainActor
    private func ensureModelDownloaded(for transcriber: SpeechTranscriber, locale: Locale) async throws {
        let supportedLocales = await SpeechTranscriber.supportedLocales
        
        guard supportedLocales.map({ $0.identifier(.bcp47) }).contains(locale.identifier(.bcp47)) else {
            throw DictationError.localeNotSupported
        }
        
        let installedLocales = await SpeechTranscriber.installedLocales
        if !installedLocales.map({ $0.identifier(.bcp47) }).contains(locale.identifier(.bcp47)) {
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                // Track download progress similarly to sample
                downloadProgress = request.progress
                try await request.downloadAndInstall()
            }
        }
    }
    
    // Optional parity: release any reserved locales when appropriate
    func deallocateSpeechAssets() async {
        let reserved = await AssetInventory.reservedLocales
        for locale in reserved {
            _ = await AssetInventory.release(reservedLocale: locale)
        }
    }
    
    // MARK: - Debug/Test Methods
    
    @MainActor
    func testCrashScenarios() async {
        debugLog("=== CRASH TEST START ===")
        
        // Test rapid start/stop cycles
        for i in 1...3 {
            debugLog("Test cycle \(i) - starting")
            
            let testBinding = Binding<String>(
                get: { "" },
                set: { value in
                    print("🎤 Text updated: '\(value)'")
                }
            )
            
            // Start recording
            await startDictation(for: testBinding)
            
            // Wait for audio processing
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            debugLog("Test cycle \(i) - stopping")
            // Stop recording
            await stopDictation()
            
            debugLog("Test cycle \(i) - completed")
            // Wait between cycles
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
        }
        
        debugLog("=== CRASH TEST END ===")
    }
}

// DictationManager is used as a singleton on the main/UI path; mark as
// unchecked Sendable to quiet strict-concurrency diagnostics for the shared instance.
extension DictationManager: @unchecked Sendable {}

enum DictationError: Error {
    case failedToSetupTranscriber
    case localeNotSupported
    case audioProcessingFailed
}

class BufferConverter {
    enum Error: Swift.Error {
        case failedToCreateConverter
        case failedToCreateConversionBuffer
        case conversionFailed(NSError?)
    }
    
    private var converter: AVAudioConverter?
    
    func convertBuffer(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        let inputFormat = buffer.format
        guard inputFormat != format else {
            return buffer
        }
        
        if converter == nil || converter?.outputFormat != format {
            converter = AVAudioConverter(from: inputFormat, to: format)
            converter?.primeMethod = .none // Sacrifice quality of first samples to avoid timestamp drift
        }
        
        guard let converter else {
            throw Error.failedToCreateConverter
        }
        
        let sampleRateRatio = converter.outputFormat.sampleRate / converter.inputFormat.sampleRate
        let scaledInputFrameLength = Double(buffer.frameLength) * sampleRateRatio
        let frameCapacity = AVAudioFrameCount(scaledInputFrameLength.rounded(.up))
        guard let conversionBuffer = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: frameCapacity) else {
            throw Error.failedToCreateConversionBuffer
        }
        
        var nsError: NSError?
        
        // Use a final class to track state within the closure safely
        final class BufferState: @unchecked Sendable {
            var processed = false
        }
        let state = BufferState()
        
        let status = converter.convert(to: conversionBuffer, error: &nsError) { packetCount, inputStatusPointer in
            defer { state.processed = true } // This closure can be called multiple times, but it only offers a single buffer
            inputStatusPointer.pointee = state.processed ? .noDataNow : .haveData
            return state.processed ? nil : buffer
        }
        
        guard status != .error else {
            throw Error.conversionFailed(nsError)
        }
        
        return conversionBuffer
    }
}
