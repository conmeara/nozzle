---
title: "Speech"
source: "https://developer.apple.com/documentation/Speech"
author:
  - "[[Apple Developer Documentation]]"
published:
created: 2025-08-28
description: "Perform speech recognition on live or prerecorded audio, and receive transcriptions, alternative interpretations, and confidence levels of the results."
tags:
  - "clippings"
---
[Skip Navigation](https://developer.apple.com/documentation/#app-main)

Perform speech recognition on live or prerecorded audio, and receive transcriptions, alternative interpretations, and confidence levels of the results.

## Overview

Use the Speech framework to recognize spoken words in recorded or live audio. The keyboard’s dictation support uses speech recognition to translate audio content into text. This framework provides a similar behavior, except that you can use it without the presence of the keyboard. For example, you might use speech recognition to recognize verbal commands or to handle text dictation in other parts of your app.

The [`SpeechTranscriber`](https://developer.apple.com/documentation/speech/speechtranscriber) class and other module classes provide specific services. The [`AssetInventory`](https://developer.apple.com/documentation/speech/assetinventory) class ensures that the system has the assets necessary to support those classes. The [`SpeechAnalyzer`](https://developer.apple.com/documentation/speech/speechanalyzer) class manages an analysis session that uses those classes.

For a general understanding of how you use these classes together, see [`SpeechAnalyzer`](https://developer.apple.com/documentation/speech/speechanalyzer).

## Topics

### Essentials

[Bringing advanced speech-to-text capabilities to your app](https://developer.apple.com/documentation/speech/bringing-advanced-speech-to-text-capabilities-to-your-app)

Learn how to incorporate live speech-to-text transcription into your app with SpeechAnalyzer.

[`actorSpeechAnalyzer`](https://developer.apple.com/documentation/speech/speechanalyzer)

Analyzes spoken audio content in various ways and manages the analysis session.

Beta

[`classAssetInventory`](https://developer.apple.com/documentation/speech/assetinventory)

Manages the assets that are necessary for transcription or other analyses.

Beta

### Modules

[`classSpeechTranscriber`](https://developer.apple.com/documentation/speech/speechtranscriber)

A speech-to-text transcription module that’s appropriate for normal conversation and general purposes.

Beta

[`classDictationTranscriber`](https://developer.apple.com/documentation/speech/dictationtranscriber)

A speech-to-text transcription module that’s similar to system dictation features and compatible with older devices.

Beta

[`classSpeechDetector`](https://developer.apple.com/documentation/speech/speechdetector)

A module that performs a voice activity detection (VAD) analysis.

Beta

[`protocolSpeechModule`](https://developer.apple.com/documentation/speech/speechmodule)

Protocol that all analyzer modules conform to.

Beta

[`protocolLocaleDependentSpeechModule`](https://developer.apple.com/documentation/speech/localedependentspeechmodule)

A module that requires locale-specific assets.

Beta

### Input and output

[`structAnalyzerInput`](https://developer.apple.com/documentation/speech/analyzerinput)

Time-coded audio data.

Beta

[`protocolSpeechModuleResult`](https://developer.apple.com/documentation/speech/speechmoduleresult)

Protocol that all module results conform to.

Beta

### Custom vocabulary

[`classSFSpeechLanguageModel`](https://developer.apple.com/documentation/speech/sfspeechlanguagemodel)

A language model built from custom training data.

[`classConfiguration`](https://developer.apple.com/documentation/speech/sfspeechlanguagemodel/configuration)

An object describing the location of a custom language model and specialized vocabulary.

[`classSFCustomLanguageModelData`](https://developer.apple.com/documentation/speech/sfcustomlanguagemodeldata)

An object that generates and exports custom language model training data.

### Asset and resource management

[`classAssetInstallationRequest`](https://developer.apple.com/documentation/speech/assetinstallationrequest)

An object that describes, downloads, and installs a selection of assets.

Beta

### Legacy API

[Speech Recognition in Objective-C](https://developer.apple.com/documentation/speech/speech-recognition-in-objc)

Use these classes to perform speech recognition in Objective-C code.

Current page is Speech