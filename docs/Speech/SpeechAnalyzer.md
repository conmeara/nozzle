---
title: "SpeechAnalyzer"
source: "https://developer.apple.com/documentation/speech/speechanalyzer"
author:
  - "[[Apple Developer Documentation]]"
published:
created: 2025-08-28
description: "Analyzes spoken audio content in various ways and manages the analysis session."
tags:
  - "clippings"
---
[Skip Navigation](https://developer.apple.com/documentation/speech/#app-main)

Analyzes spoken audio content in various ways and manages the analysis session.

```
final actor SpeechAnalyzer
```

## Overview

The Speech framework provides several modules that can be added to an analyzer to provide specific types of analysis and transcription. Many use cases only need a [`SpeechTranscriber`](https://developer.apple.com/documentation/speech/speechtranscriber) module, which performs speech-to-text transcriptions.

The `SpeechAnalyzer` class is responsible for:

- Holding associated modules
- Accepting audio speech input
- Controlling the overall analysis

Each module is responsible for:

- Providing guidance on acceptable input
- Providing its analysis or transcription output

Analysis is asynchronous. Input, output, and session control are decoupled and typically occur over several different tasks created by you or by the session. In particular, where an Objective-C API might use a delegate to provide results to you, the Swift API’s modules provides their results via an `AsyncSequence`. Similarly, you provide speech input to this API via an `AsyncSequence` you create and populate.

The analyzer can only analyze one input sequence at a time.

### Perform analysis

To perform analysis on audio files and streams, follow these general steps:

1. Create and configure the necessary modules.
2. Ensure the relevant assets are installed or already present. See [`AssetInventory`](https://developer.apple.com/documentation/speech/assetinventory).
3. Create an input sequence you can use to provide the spoken audio.
4. Create and configure the analyzer with the modules and input sequence.
5. Supply audio.
6. Start analysis.
7. Act on results.
8. Finish analysis when desired.

This example shows how you could perform an analysis that transcribes audio using the `SpeechTranscriber` module:

```
import Speech

// Step 1: Modules

guard let locale = SpeechTranscriber.supportedLocale(equivalentTo: Locale.current) else {

    /* Note unsupported language */

}

let transcriber = SpeechTranscriber(locale: locale, preset: .offlineTranscription)

// Step 2: Assets

if let installationRequest = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {

    try await installationRequest.downloadAndInstall()

}

// Step 3: Input sequence

let (inputSequence, inputBuilder) = AsyncStream.makeStream(of: AnalyzerInput.self)

// Step 4: Analyzer

let audioFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])

let analyzer = SpeechAnalyzer(modules: [transcriber])

// Step 5: Supply audio

Task {

    while /* audio remains */ {

        /* Get some audio */

        /* Convert to audioFormat */

        let pcmBuffer = /* an AVAudioPCMBuffer containing some converted audio */

        let input = AnalyzerInput(buffer: pcmBuffer)

        inputBuilder.yield(input)

    }

    inputBuilder.finish()

}

// Step 7: Act on results

Task {

    do {

        for try await result in transcriber.results {

            let bestTranscription = result.text // an AttributedString

            let plainTextBestTranscription = String(bestTranscription.characters) // a String

            print(plainTextBestTranscription)

        }

    } catch {

        /* Handle error */

    }

}

// Step 6: Perform analysis

let lastSampleTime = try await analyzer.analyzeSequence(inputSequence)

// Step 8: Finish analysis

if let lastSampleTime {

    try await analyzer.finalizeAndFinish(through: lastSampleTime)

} else {

    try analyzer.cancelAndFinishNow()

}
```

### Analyze audio files

To analyze one or more audio files represented by an `AVAudioFile` object, call methods such as [`analyzeSequence(from:)`](https://developer.apple.com/documentation/speech/speechanalyzer/analyzesequence\(from:\)) or [`start(inputAudioFile:finishAfterFile:)`](https://developer.apple.com/documentation/speech/speechanalyzer/start\(inputaudiofile:finishafterfile:\)), or create the analyzer with one of the initializers that has a file parameter. These methods automatically convert the file to a supported audio format and process the file in its entirety.

To end the analysis session after one file, pass `true` for the `finishAfterFile` parameter or call one of the `finish` methods.

Otherwise, by default, the analyzer won’t terminate its result streams and will wait for additional audio files or buffers. The analysis session doesn’t reset the audio timeline after each file; the next audio is assumed to come immediately after the completed file.

### Analyze audio buffers

To analyze audio buffers directly, convert them to a supported audio format, either on the fly or in advance. You can use [`bestAvailableAudioFormat(compatibleWith:)`](https://developer.apple.com/documentation/speech/speechanalyzer/bestavailableaudioformat\(compatiblewith:\)) or individual modules’ [`availableCompatibleAudioFormats`](https://developer.apple.com/documentation/speech/speechmodule/availablecompatibleaudioformats) methods to select a format to convert to.

Create an [`AnalyzerInput`](https://developer.apple.com/documentation/speech/analyzerinput) object for each audio buffer and add the object to an input sequence you create. Supply that input sequence to [`analyzeSequence(_:)`](https://developer.apple.com/documentation/speech/speechanalyzer/analyzesequence\(_:\)), [`start(inputSequence:)`](https://developer.apple.com/documentation/speech/speechanalyzer/start\(inputsequence:\)), or a similar parameter of the analyzer’s initializer.

To skip past part of an audio stream, omit the buffers you want to skip from the input sequence. When you resume analysis with a later buffer, you can ensure the time-code of each module’s result accounts for the skipped audio. To do this, pass the later buffer’s time-code within the audio stream as the `bufferStartTime` parameter of the later `AnalyzerInput` object.

### Analyze autonomously

You can and usually should perform analysis using the [`analyzeSequence(_:)`](https://developer.apple.com/documentation/speech/speechanalyzer/analyzesequence\(_:\)) or [`analyzeSequence(from:)`](https://developer.apple.com/documentation/speech/speechanalyzer/analyzesequence\(from:\)) methods; those methods work well with Swift structured concurrency techniques. However, you may prefer that the analyzer proceed independently and perform its analysis autonomously as audio input becomes available in a task managed by the analyzer itself.

To use this capability, create the analyzer with one of the initializers that has an input sequence or file parameter, or call [`start(inputSequence:)`](https://developer.apple.com/documentation/speech/speechanalyzer/start\(inputsequence:\)) or [`start(inputAudioFile:finishAfterFile:)`](https://developer.apple.com/documentation/speech/speechanalyzer/start\(inputaudiofile:finishafterfile:\)). To end the analysis when the input ends, call [`finalizeAndFinishThroughEndOfInput()`](https://developer.apple.com/documentation/speech/speechanalyzer/finalizeandfinishthroughendofinput\(\)). To end the analysis of that input and start analysis of different input, call one of the `start` methods again.

### Control processing and timing of results

Modules deliver results periodically, but you can manually synchronize their processing and delivery to outside cues.

To deliver a result for a particular time-code, call [`finalize(through:)`](https://developer.apple.com/documentation/speech/speechanalyzer/finalize\(through:\)). To cancel processing of results that are no longer of interest, call [`cancelAnalysis(before:)`](https://developer.apple.com/documentation/speech/speechanalyzer/cancelanalysis\(before:\)).

### Improve responsiveness

By default, the analyzer and modules load the system resources that they require lazily, and unload those resources when they’re deallocated.

To proactively load system resources and “preheat” the analyzer, call [`prepareToAnalyze(in:)`](https://developer.apple.com/documentation/speech/speechanalyzer/preparetoanalyze\(in:\)) after setting its modules. This may improve how quickly the modules return their first results.

To delay or prevent unloading an analyzer’s resources — caching them for later use by a different analyzer instance — you can select a [`SpeechAnalyzer.Options.ModelRetention`](https://developer.apple.com/documentation/speech/speechanalyzer/options/modelretention-swift.enum) option and create the analyzer with an appropriate [`SpeechAnalyzer.Options`](https://developer.apple.com/documentation/speech/speechanalyzer/options) object.

To set the priority of analysis work, create the analyzer with a [`SpeechAnalyzer.Options`](https://developer.apple.com/documentation/speech/speechanalyzer/options) object given a `priority` value.

Specific modules may also offer options that improve responsiveness.

### Finish analysis

To end an analysis session, you must use one of the analyzer’s `finish` methods or parameters, or deallocate the analyzer.

When the analysis session transitions to the *finished* state:

- The analyzer won’t take additional input from the input sequence
- Most methods won’t do anything; in particular, the analyzer won’t accept different input sequences or modules
- Module result streams terminate and modules won’t publish additional results, though the app can continue to iterate over already-published results

When the analyzer or its modules’ result streams throw an error, the analysis session becomes finished as described above, and the same error (or a `CancellationError`) is thrown from all waiting methods and result streams.

## Topics

### Creating an analyzer

[`convenienceinit(modules: [any SpeechModule], options: SpeechAnalyzer.Options?)`](https://developer.apple.com/documentation/speech/speechanalyzer/init\(modules:options:\))

Creates an analyzer.

[`convenienceinit<InputSequence>(inputSequence: InputSequence, modules: [any SpeechModule], options: SpeechAnalyzer.Options?, analysisContext: AnalysisContext, volatileRangeChangedHandler: sending ((CMTimeRange, Bool, Bool) -> Void)?)`](https://developer.apple.com/documentation/speech/speechanalyzer/init\(inputsequence:modules:options:analysiscontext:volatilerangechangedhandler:\))

Creates an analyzer and begins analysis.

[`convenienceinit(inputAudioFile: AVAudioFile, modules: [any SpeechModule], options: SpeechAnalyzer.Options?, analysisContext: AnalysisContext, finishAfterFile: Bool, volatileRangeChangedHandler: sending ((CMTimeRange, Bool, Bool) -> Void)?) asyncthrows`](https://developer.apple.com/documentation/speech/speechanalyzer/init\(inputaudiofile:modules:options:analysiscontext:finishafterfile:volatilerangechangedhandler:\))

Creates an analyzer and begins analysis on an audio file.

[`structOptions`](https://developer.apple.com/documentation/speech/speechanalyzer/options)

Analysis processing options.

### Managing modules

[`funcsetModules([any SpeechModule]) asyncthrows`](https://developer.apple.com/documentation/speech/speechanalyzer/setmodules\(_:\))

Adds or removes modules.

[`varmodules: [any SpeechModule]`](https://developer.apple.com/documentation/speech/speechanalyzer/modules)

The modules performing analysis on the audio input.

### Performing analysis

[`funcanalyzeSequence<InputSequence>(InputSequence) asyncthrows -> CMTime?`](https://developer.apple.com/documentation/speech/speechanalyzer/analyzesequence\(_:\))

Analyzes an input sequence, returning when the sequence is consumed.

[`funcanalyzeSequence(from: AVAudioFile) asyncthrows -> CMTime?`](https://developer.apple.com/documentation/speech/speechanalyzer/analyzesequence\(from:\))

Analyzes an input sequence created from an audio file, returning when the file has been read.

### Performing autonomous analysis

[`funcstart<InputSequence>(inputSequence: InputSequence) asyncthrows`](https://developer.apple.com/documentation/speech/speechanalyzer/start\(inputsequence:\))

Starts analysis of an input sequence and returns immediately.

[`funcstart(inputAudioFile: AVAudioFile, finishAfterFile: Bool) asyncthrows`](https://developer.apple.com/documentation/speech/speechanalyzer/start\(inputaudiofile:finishafterfile:\))

Starts analysis of an input sequence created from an audio file and returns immediately.

### Finalizing and cancelling results

[`funccancelAnalysis(before: CMTime)`](https://developer.apple.com/documentation/speech/speechanalyzer/cancelanalysis\(before:\))

Stops analyzing audio predating the given time.

[`funcfinalize(through: CMTime?) asyncthrows`](https://developer.apple.com/documentation/speech/speechanalyzer/finalize\(through:\))

Finalizes the modules’ analyses.

### Finishing analysis

[`funccancelAndFinishNow() async`](https://developer.apple.com/documentation/speech/speechanalyzer/cancelandfinishnow\(\))

Finishes analysis immediately.

[`funcfinalizeAndFinishThroughEndOfInput() asyncthrows`](https://developer.apple.com/documentation/speech/speechanalyzer/finalizeandfinishthroughendofinput\(\))

Finishes analysis after an audio input sequence has been fully consumed and its results are finalized.

[`funcfinalizeAndFinish(through: CMTime) asyncthrows`](https://developer.apple.com/documentation/speech/speechanalyzer/finalizeandfinish\(through:\))

Finishes analysis after finalizing results for a given time-code.

[`funcfinish(after: CMTime) asyncthrows`](https://developer.apple.com/documentation/speech/speechanalyzer/finish\(after:\))

Finishes analysis once input for a given time is consumed.

### Determining audio formats

[`staticfuncbestAvailableAudioFormat(compatibleWith: [any SpeechModule]) async -> AVAudioFormat?`](https://developer.apple.com/documentation/speech/speechanalyzer/bestavailableaudioformat\(compatiblewith:\))

Retrieves the best-quality audio format that the specified modules can work with, from assets installed on the device.

[`staticfuncbestAvailableAudioFormat(compatibleWith: [any SpeechModule], considering: AVAudioFormat?) async -> AVAudioFormat?`](https://developer.apple.com/documentation/speech/speechanalyzer/bestavailableaudioformat\(compatiblewith:considering:\))

Retrieves the best-quality audio format that the specified modules can work with, taking into account the natural format of the audio and assets installed on the device.

### Improving responsiveness

[`funcprepareToAnalyze(in: AVAudioFormat?) asyncthrows`](https://developer.apple.com/documentation/speech/speechanalyzer/preparetoanalyze\(in:\))

Prepares the analyzer to begin work with minimal startup delay.

[`funcprepareToAnalyze(in: AVAudioFormat?, withProgressReadyHandler: sending ((Progress) -> Void)?) asyncthrows`](https://developer.apple.com/documentation/speech/speechanalyzer/preparetoanalyze\(in:withprogressreadyhandler:\))

Prepares the analyzer to begin work with minimal startup delay, reporting the progress of that preparation.

### Monitoring analysis

[`funcsetVolatileRangeChangedHandler(sending ((CMTimeRange, Bool, Bool) -> Void)?)`](https://developer.apple.com/documentation/speech/speechanalyzer/setvolatilerangechangedhandler\(_:\))

A closure that the analyzer calls when the volatile range changes.

[`varvolatileRange: CMTimeRange?`](https://developer.apple.com/documentation/speech/speechanalyzer/volatilerange)

The range of results that can change.

### Managing contexts

[`funcsetContext(AnalysisContext) asyncthrows`](https://developer.apple.com/documentation/speech/speechanalyzer/setcontext\(_:\))

Sets contextual information to improve or inform the analysis.

[`varcontext: AnalysisContext`](https://developer.apple.com/documentation/speech/speechanalyzer/context)

An object containing contextual information.

## Relationships

### Conforms To

- [`Actor`](https://developer.apple.com/documentation/Swift/Actor)
- [`Sendable`](https://developer.apple.com/documentation/Swift/Sendable)
- [`SendableMetatype`](https://developer.apple.com/documentation/Swift/SendableMetatype)

## See Also

### Essentials

[Bringing advanced speech-to-text capabilities to your app](https://developer.apple.com/documentation/speech/bringing-advanced-speech-to-text-capabilities-to-your-app)

Learn how to incorporate live speech-to-text transcription into your app with SpeechAnalyzer.

[`classAssetInventory`](https://developer.apple.com/documentation/speech/assetinventory)

Manages the assets that are necessary for transcription or other analyses.

Beta

Beta Software

This documentation contains preliminary information about an API or technology in development. This information is subject to change, and software implemented according to this documentation should be tested with final operating system software.

[Learn more about using Apple's beta software](https://developer.apple.com/support/beta-software/)

Current page is SpeechAnalyzer