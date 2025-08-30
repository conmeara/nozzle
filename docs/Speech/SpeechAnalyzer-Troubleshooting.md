# SpeechAnalyzer integration: troubleshooting + fixes

Last updated: 2025-08-29

## Summary

- Symptom: App crashed or behaved erratically when starting/stopping dictation using Apple’s new SpeechAnalyzer/SpeechTranscriber APIs.
- Status: No crashes after fixes; a few benign framework logs may still appear.
- Root causes: a mix of concurrency isolation issues, unnecessary audio file I/O during capture, locale handling, and over-broad entitlements triggering system lookups (DetachedSignatures).

## Notable logs observed

- `os_unix.c:51040: open(/private/var/db/DetachedSignatures) - No such file or directory`
- `AddInstanceForFactory: No factory registered ...` and `throwing -10877`
- `-[AFPreferences _languageCodeWithFallback:] No language code saved, but Assistant is enabled`
- `AFIsDeviceGreymatterEligible Missing entitlements for os_eligibility lookup`

These lines are often symptomatic of component scans or system lookups; they are reduced or benign after the changes below.

## What we changed

1) Non-blocking streaming
- Before: `startDictation` awaited the streaming loop indirectly, risking actor contention and shutdown hazards.
- After: Start audio streaming in a detached task and do not await from UI code. On stop, cancel the task first.
- Files: `nozzle/Observables/DictationManager.swift`

2) Remove audio file writes inside the input tap
- Before: We created an `AVAudioFile` and wrote every tap buffer to disk (sample-app convenience), potentially triggering AudioUnit/component work and file-system interactions.
- After: Removed all file I/O from the tap callback. We only yield buffers to the analyzer.
- Files: `nozzle/Observables/DictationManager.swift`

3) Locale selection and preheating
- Before: Relied on current locale without confirming support; could fall into odd framework fallback paths (AFPreferences logs).
- After: Resolve a supported locale from `SpeechTranscriber.supportedLocales` and preheat with `prepareToAnalyze(in:)`.
- Files: `nozzle/Observables/DictationManager.swift`

4) Privacy/entitlements
- Added `NSSpeechRecognitionUsageDescription` to `Info.plist`.
- Removed `com.apple.security.temporary-exception.audio-unit` entitlement to avoid AU scan/DetachedSignatures paths.
- Files: `nozzle/Info.plist`, `nozzle/nozzle.entitlements`

5) Concurrency correctness for singleton and logging
- Removed class-level `@MainActor` and annotated only UI-touching methods.
- Logging from detached task now hops back to the main actor.
- Marked `DictationManager` as `@unchecked Sendable` to quiet strict-concurrency for the shared singleton.
- Files: `nozzle/Observables/DictationManager.swift`

6) Actor isolation in file monitoring
- Fixed main-actor isolated state (`pendingPaths`) being mutated from a background FSEvents queue.
- Ingest on background queue; hop to `@MainActor` to update state and coalesce apply.
- Files: `nozzle/Observables/FileSystemSource.swift`

7) SwiftUI API updates
- Updated deprecated `.onChange(of:)` uses to the modern two-parameter closure form where flagged.
- Files: `nozzle/Views/Preview/PromptEditorView.swift`, `nozzle/Settings/PinsSettingsPane.swift`

## Why this works

- Detached streaming avoids blocking the main actor and reduces teardown races with the audio tap and engine.
- Removing on-the-fly file writes eliminates unnecessary AudioUnit/component initialization that can provoke failures (`-10877`) and signature DB checks.
- Explicit supported-locale selection avoids AF/Assistant fallback codepaths.
- Preheating the analyzer reduces first-result latency and late resource loading.
- Tightening actor boundaries prevents cross-actor data races and “actor-isolated” diagnostics that can lead to undefined behavior.
- Adjusting entitlements stops framework codepaths that access system locations not available in the sandbox.

## Validation checklist

- Start/stop dictation multiple times; verify no crashes.
- Observe logs: expect to see
  - Transcriber setup → Audio tap installed → Engine started
  - Tap callbacks printing frames
- Confirm transcription appears in the prompt field (volatile → finalized).
- Verify microphone permission prompt and behavior.

## Lessons learned

- Mirror Apple’s sample architecture, but omit sample-only conveniences (e.g., writing buffers to a file) in production capture paths.
- Be surgical with actors: prefer method-level `@MainActor` for UI updates rather than class-level on coordinators that interact with audio threads.
- Always resolve a supported locale and install assets with `AssetInventory` before starting analysis.
- Preheat analyzers when possible to avoid slow first tokens.
- Avoid broad/temporary entitlements that may trigger unwanted system codepaths, especially around AudioUnits.
- In Swift 6, prefer the new `.onChange` signatures and address strict-concurrency warnings proactively (e.g., `@unchecked Sendable` on process-wide singletons with disciplined access).

## References

- Apple sample: Bringing advanced speech-to-text capabilities (docs/Speech/BringingAdvancedSpeechToTextCapabilitiesToYourApp)
- Our implementation: `nozzle/Observables/DictationManager.swift`
- Speech docs in repo: `docs/Speech/*.md`

## Future improvements

- Show `AssetInstallationRequest.progress` in UI during first-time model download.
- Consider a `DictationTranscriber` fallback for broader device coverage.
- Persist an analyzer instance or preheating at app launch for faster start.
- Add guardrails to prevent starting dictation without a supported locale.

# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and this project aims to follow Semantic Versioning where practical.

## [Unreleased] – 2025-08-29

### Added
- SpeechAnalyzer troubleshooting guide: docs/Speech/SpeechAnalyzer-Troubleshooting.md.
- `NSSpeechRecognitionUsageDescription` in Info.plist to clarify on-device speech recognition usage.
- Analyzer preheating (`prepareToAnalyze(in:)`) and supported-locale selection helper for SpeechTranscriber.

### Changed
- DictationManager: start audio streaming on a detached task; do not block the main actor during dictation start/stop.
- Removed audio file writes from the input tap (sample-app behavior only); now we only stream buffers to the analyzer.
- Updated deprecated SwiftUI `.onChange(of:)` usages to the modern two-parameter closure form where flagged.

### Fixed
- Crashes when starting/stopping dictation by addressing actor isolation and teardown order.
- Concurrency diagnostics for the dictation singleton by marking `DictationManager` as `@unchecked Sendable` and scoping `@MainActor` to UI methods.
- FileSystemSource actor isolation: mutate `pendingPaths` only on the main actor; ingest events on background queue and coalesce apply on main.
- Async/await mismatch in locale handling for SpeechTranscriber.

### Security
- Removed `com.apple.security.temporary-exception.audio-unit` entitlement to avoid unnecessary AudioUnit/component scans and system signature DB lookups.

### Notes
- Some benign framework logs (e.g., AFPreferences/Greymatter) may still appear; they do not impact functionality.
- See the troubleshooting guide for rationale, validation steps, and lessons learned.
