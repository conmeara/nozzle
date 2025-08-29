---
title: "SystemLanguageModel"
source: "https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel"
author:
  - "[[Apple Developer Documentation]]"
published:
created: 2025-08-28
description: "An on-device large language model capable of text generation tasks."
tags:
  - "clippings"
---
[Skip Navigation](https://developer.apple.com/documentation/foundationmodels/#app-main)

An on-device large language model capable of text generation tasks.

```
final class SystemLanguageModel
```

## Mentioned in

[Improving the safety of generative model output](https://developer.apple.com/documentation/foundationmodels/improving-the-safety-of-generative-model-output)

[Generating content and performing tasks with Foundation Models](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models)

[Loading and using a custom adapter with Foundation Models](https://developer.apple.com/documentation/foundationmodels/loading-and-using-a-custom-adapter-with-foundation-models)

## Overview

The `SystemLanguageModel` refers to the on-device text foundation model that powers Apple Intelligence. Use [`default`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/default) to access the base version of the model and perform general-purpose text generation tasks. To access a specialized version of the model, initialize the model with [`SystemLanguageModel.UseCase`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/usecase) to perform tasks like [`contentTagging`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/usecase/contenttagging).

Verify the model availability before you use the model. Model availability depends on device factors like:

- The device must support Apple Intelligence.
- Apple Intelligence must be turned on in Settings.

Use [`SystemLanguageModel.Availability`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum) to change what your app shows to people based on the availability condition:

## Topics

[`convenienceinit(useCase: SystemLanguageModel.UseCase, guardrails: SystemLanguageModel.Guardrails)`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/init\(usecase:guardrails:\))

Creates a system language model for a specific use case.

[`structUseCase`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/usecase)

A type that represents the use case for prompting.

[`structGuardrails`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/guardrails)

Guardrails flag sensitive content from model input and output.

[Loading and using a custom adapter with Foundation Models](https://developer.apple.com/documentation/foundationmodels/loading-and-using-a-custom-adapter-with-foundation-models)

Specialize the behavior of the system language model by using a custom adapter you train.

[`com.apple.developer.foundation-model-adapter`](https://developer.apple.com/documentation/BundleResources/Entitlements/com.apple.developer.foundation-model-adapter)

A Boolean value that indicates whether the app can enable custom adapters for the Foundation Models framework.

[`convenienceinit(adapter: SystemLanguageModel.Adapter, guardrails: SystemLanguageModel.Guardrails)`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/init\(adapter:guardrails:\))

Creates the base version of the model with an adapter.

[`structAdapter`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/adapter)

Specializes the system language model for custom use cases.

### Checking model availability

[`varisAvailable: Bool`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/isavailable)

A convenience getter to check if the system is entirely ready.

[`varavailability: SystemLanguageModel.Availability`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.property)

The availability of the language model.

[`enumAvailability`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum)

The availability status for a specific system language model.

### Retrieving the supported languages

[`varsupportedLanguages: Set<Locale.Language>`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/supportedlanguages)

Languages that the model supports.

### Getting the default model

[``staticlet`default`: SystemLanguageModel``](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/default)

The base version of the model.

### Instance Methods

[`funcsupportsLocale(Locale) -> Bool`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/supportslocale\(_:\))

Returns a Boolean indicating whether the given locale is supported by the model.

## Relationships

### Conforms To

- [`Copyable`](https://developer.apple.com/documentation/Swift/Copyable)
- [`Observable`](https://developer.apple.com/documentation/Observation/Observable)
- [`Sendable`](https://developer.apple.com/documentation/Swift/Sendable)
- [`SendableMetatype`](https://developer.apple.com/documentation/Swift/SendableMetatype)

## See Also

### Essentials

[Generating content and performing tasks with Foundation Models](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models)

Enhance the experience in your app by prompting an on-device large language model.

[Improving the safety of generative model output](https://developer.apple.com/documentation/foundationmodels/improving-the-safety-of-generative-model-output)

Create generative experiences that appropriately handle sensitive inputs and respect people.

[Support languages and locales with Foundation Models](https://developer.apple.com/documentation/foundationmodels/support-languages-and-locales-with-foundation-models)

Generate content in the language people prefer when they interact with your app.

[Adding intelligent app features with generative models](https://developer.apple.com/documentation/foundationmodels/adding-intelligent-app-features-with-generative-models)

Build robust apps with guided generation and tool calling by adopting the Foundation Models framework.

[`structUseCase`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/usecase)

A type that represents the use case for prompting.

Beta

Beta Software

This documentation contains preliminary information about an API or technology in development. This information is subject to change, and software implemented according to this documentation should be tested with final operating system software.

[Learn more about using Apple's beta software](https://developer.apple.com/support/beta-software/)

Current page is SystemLanguageModel