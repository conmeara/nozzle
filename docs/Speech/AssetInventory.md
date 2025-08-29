---
title: "AssetInventory"
source: "https://developer.apple.com/documentation/speech/assetinventory"
author:
  - "[[Apple Developer Documentation]]"
published:
created: 2025-08-29
description: "Manages the assets that are necessary for transcription or other analyses."
tags:
  - "clippings"
---
[Skip Navigation](https://developer.apple.com/documentation/speech/#app-main)

Manages the assets that are necessary for transcription or other analyses.

```
final class AssetInventory
```

## Overview

Before using the [`SpeechAnalyzer`](https://developer.apple.com/documentation/speech/speechanalyzer) class, you must install assets required by the modules you plan to use. These assets are machine-learning models downloaded from Apple’s servers and managed by the system. Once you download, install, or use an asset, the system retains and updates it automatically, and shares it with other apps. The system makes a certain number of locale-specific asset reservations available to your app to limit storage space and network usage.

Your app does not work with assets directly. Instead, your app configures module objects. The system uses the modules’ configuration to determine what assets are relevant.

### Install assets

Installing an asset is a four-step process:

1. Create analyzer modules in the configurations that you wish to use. These modules can be discarded when no longer needed; the system installs assets using the modules’ configuration, not their object identity.
2. Assign your app’s asset reservations to those locales. The class does this automatically if needed, but you can also call [`reserve(locale:)`](https://developer.apple.com/documentation/speech/assetinventory/reserve\(locale:\)) to do this manually. This step is only necessary for modules with locale-specific assets; that is, modules conforming to [`LocaleDependentSpeechModule`](https://developer.apple.com/documentation/speech/localedependentspeechmodule). You can skip this step for other modules.
3. Start downloading the required assets for the modules’ configuration. Call [`assetInstallationRequest(supporting:)`](https://developer.apple.com/documentation/speech/assetinventory/assetinstallationrequest\(supporting:\)) to obtain an instance of [`AssetInstallationRequest`](https://developer.apple.com/documentation/speech/assetinstallationrequest) and call its [`downloadAndInstall()`](https://developer.apple.com/documentation/speech/assetinstallationrequest/downloadandinstall\(\)) method.
4. Wait for the download to finish. Note that the download may finish immediately; the assets may have already been downloaded if the assets were preinstalled on the system, another app already downloaded them, or a previous module configuration used the same assets.

Once assets are downloaded, they persist between app launches and are shared between apps. The system may unsubscribe your app from assets that haven’t been used in a while.

### Manage assets

When your app no longer needs assets for a particular locale, call [`release(reservedLocale:)`](https://developer.apple.com/documentation/speech/assetinventory/release\(reservedlocale:\)) to free up that reservation. The system will remove the assets at a later time.

## Topics

[`staticfuncassetInstallationRequest(supporting: [any SpeechModule]) asyncthrows -> AssetInstallationRequest?`](https://developer.apple.com/documentation/speech/assetinventory/assetinstallationrequest\(supporting:\))

Returns an installation request object, which is used to initiate the asset download and monitor its progress.

### Checking asset status

[`staticfuncstatus(forModules: [any SpeechModule]) async -> AssetInventory.Status`](https://developer.apple.com/documentation/speech/assetinventory/status\(formodules:\))

Returns the status for the list of modules.

[`enumStatus`](https://developer.apple.com/documentation/speech/assetinventory/status)

### Type Properties

[`staticvarmaximumReservedLocales: Int`](https://developer.apple.com/documentation/speech/assetinventory/maximumreservedlocales)

The number of locale reservations permitted to an app.

[`staticvarreservedLocales: [Locale]`](https://developer.apple.com/documentation/speech/assetinventory/reservedlocales)

The app’s current asset locale reservations.

### Type Methods

[`staticfuncrelease(reservedLocale: Locale) async -> Bool`](https://developer.apple.com/documentation/speech/assetinventory/release\(reservedlocale:\))

Removes an asset locale reservation.

[`staticfuncreserve(locale: Locale) asyncthrows -> Bool`](https://developer.apple.com/documentation/speech/assetinventory/reserve\(locale:\))

Add an asset locale to the app’s current reservations.

## See Also

### Essentials

[Bringing advanced speech-to-text capabilities to your app](https://developer.apple.com/documentation/speech/bringing-advanced-speech-to-text-capabilities-to-your-app)

Learn how to incorporate live speech-to-text transcription into your app with SpeechAnalyzer.

[`actorSpeechAnalyzer`](https://developer.apple.com/documentation/speech/speechanalyzer)

Analyzes spoken audio content in various ways and manages the analysis session.

Beta

Beta Software

This documentation contains preliminary information about an API or technology in development. This information is subject to change, and software implemented according to this documentation should be tested with final operating system software.

[Learn more about using Apple's beta software](https://developer.apple.com/support/beta-software/)

Current page is AssetInventory