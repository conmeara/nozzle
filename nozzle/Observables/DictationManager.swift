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
    
    private var isCleaningUp: Bool = false
    
    var isRecording = false
    // Match sample: keep attributed transcripts for styling and timing
    var volatileTranscript: AttributedString = ""
    var finalizedTranscript: AttributedString = ""
    
    // Optional: expose download progress similar to sample
    var downloadProgress: Progress?
    
    private var targetTextBinding: Binding<String>?
    private var analyzerFormat: AVAudioFormat?
    // Store the original text before dictation starts to prevent duplication
    private var originalText: String = ""
    // Streaming task so we don't block the main actor
    private var audioStreamTask: Task<Void, Never>?
    
    init() {} // engine created above
    
    
    @MainActor
    func toggleDictation(for textBinding: Binding<String>) async {
        if isRecording {
            await stopDictation(saveTranscription: true)
        } else {
            await startDictation(for: textBinding)
        }
    }
    
    @MainActor
    private func startDictation(for textBinding: Binding<String>) async {
        guard await requestMicrophonePermission() else {
            return
        }
        
        targetTextBinding = textBinding
        originalText = textBinding.wrappedValue
        finalizedTranscript = ""
        volatileTranscript = ""
        
        // Play dictation start sound
        NSSound.dictationBegin?.play()
        
        isRecording = true
        
        do {
            try await setupTranscriber()
            
            // Start audio streaming on a detached task; don't await here
            audioStreamTask = Task.detached(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                do {
                    try await self.startAudioStream()
                } catch {
                    // Hop to main for logging to avoid cross-actor diagnostics
                }
            }
        
        } catch {
            isRecording = false
        }
    }
    
    @MainActor
    func stopDictation(saveTranscription: Bool = true) async {
        isCleaningUp = true
        isRecording = false
        
        // Play dictation stop sound
        NSSound.dictationConfirm?.play()
        
        // Clean shutdown sequence - follow proper order
        // 0. Cancel streaming task if running
        audioStreamTask?.cancel()
        audioStreamTask = nil

        // 1. Stop audio engine
        audioEngine.stop()
        
        // 2. Clear continuation to stop yielding buffers
        audioStreamContinuation?.finish()
        audioStreamContinuation = nil
        
        // 3. Add small delay for audio thread cleanup
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // 4. Remove tap safely
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // 5. No file to clear; keep the engine instance (sample behavior)
        
        // Finish analyzer input
        inputBuilder?.finish()
        inputBuilder = nil
        
        // 6. Wait for analyzer to finish
        if let analyzer = analyzer {
            try? await analyzer.finalizeAndFinishThroughEndOfInput()
        }
        
        // 7. Cancel recognition task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Handle transcription based on saveTranscription parameter
        if saveTranscription {
            // Final text is already in the binding from updateTargetText() calls
        } else {
            // Restore original text (cancel transcription)
            if let binding = targetTextBinding {
                binding.wrappedValue = originalText
            }
        }
        
        // Clean up
        targetTextBinding = nil
        finalizedTranscript = ""
        volatileTranscript = ""
        transcriber = nil
        analyzer = nil
        isCleaningUp = false
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
        
        // Build the complete transcription for this session
        var sessionTranscript = String(finalizedTranscript.characters)
        if !volatileTranscript.characters.isEmpty {
            let separator = sessionTranscript.isEmpty ? "" : " "
            sessionTranscript += separator + String(volatileTranscript.characters)
        }
        
        // Show original text + current session transcription
        if !sessionTranscript.isEmpty {
            let separator = originalText.isEmpty ? "" : " "
            binding.wrappedValue = originalText + separator + sessionTranscript
        } else {
            binding.wrappedValue = originalText
        }
    }
    
    // Not @MainActor - audio operations need to run on appropriate threads
    private func startAudioStream() async throws {
        
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .spokenAudio)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
        
        // Setup audio engine
        try setupAudioEngine()
        
        // Create audio stream using the fixed pattern
        let audioStream = try audioStream()
        
        // Process buffers as they arrive (no timeout, sample parity)
        for await buffer in audioStream {
            guard isRecording else { break }
            try await streamAudioToTranscriber(buffer)
        }
    }
    
    private func setupAudioEngine() throws {
        let inputNode = audioEngine.inputNode
        
        // Remove any existing tap
        inputNode.removeTap(onBus: 0)
    }
    
    private func audioStream() throws -> AsyncStream<AVAudioPCMBuffer> {
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(
            onBus: 0,
            bufferSize: 4096,
            format: inputNode.outputFormat(forBus: 0)
        ) { [weak self] (buffer, time) in
            guard let self else { return }
            
            
            // Yield buffer to continuation
            self.audioStreamContinuation?.yield(buffer)
        }
        
        
        // Apple's exact sequence: prepare, start, THEN create stream
        audioEngine.prepare()
        try audioEngine.start()
        
        return AsyncStream(AVAudioPCMBuffer.self, bufferingPolicy: .unbounded) { continuation in
            self.audioStreamContinuation = continuation
        }
    }
    
    // Not on the main actor, like the sample's transcriber path
    private func streamAudioToTranscriber(_ buffer: AVAudioPCMBuffer) async throws {
        guard let inputBuilder = inputBuilder,
              let analyzerFormat = analyzerFormat else {
            throw DictationError.audioProcessingFailed
        }
        
        
        do {
            let converted = try bufferConverter.convertBuffer(buffer, to: analyzerFormat)
            inputBuilder.yield(AnalyzerInput(buffer: converted))
        } catch {
            throw error
        }
    }
    
    // Not @MainActor - permission checks can happen on any thread
    private func requestMicrophonePermission() async -> Bool {
        #if os(macOS)
        // On macOS, check authorization status (no device enumeration to avoid CMIO errors)
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch currentStatus {
        case .authorized:
            return true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            return granted
        case .denied, .restricted:
            return false
        @unknown default:
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
    
    
    @MainActor
    func cancelDictation() async {
        // Play cancel sound and stop without saving
        NSSound.dictationCancel?.play()
        await stopDictation(saveTranscription: false)
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
