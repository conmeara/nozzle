---
title: "Materials"
source: "https://developer.apple.com/design/human-interface-guidelines/materials"
author:
  - "[[Apple Developer Documentation]]"
published:
created: 2025-08-31
description: "A material is a visual effect that creates a sense of depth, layering, and hierarchy between foreground and background elements."
tags:
  - "clippings"
---
[Skip Navigation](https://developer.apple.com/design/human-interface-guidelines/#app-main)

A material is a visual effect that creates a sense of depth, layering, and hierarchy between foreground and background elements.

![A sketch of overlapping squares, suggesting the use of transparency to hint at background content. The image is overlaid with rectangular and circular grid lines and is tinted yellow to subtly reflect the yellow in the original six-color Apple logo.](https://docs-assets.developer.apple.com/published/b47eb524ca1170cd60312070b9822dd4/foundations-materials-intro~dark%402x.png)

Materials help visually separate foreground elements, such as text and controls, from background elements, such as content and solid colors. By allowing color to pass through from background to foreground, a material establishes visual hierarchy to help people more easily retain a sense of place.

Apple platforms feature two types of materials: Liquid Glass, and standard materials. [Liquid Glass](https://developer.apple.com/design/human-interface-guidelines/materials#Liquid-Glass) is a dynamic material that unifies the design language across Apple platforms, allowing you to present controls and navigation without obscuring underlying content. In contrast to Liquid Glass, the [standard materials](https://developer.apple.com/design/human-interface-guidelines/materials#Standard-materials) help with visual differentiation within the content layer.

## Liquid Glass

Liquid Glass forms a distinct functional layer for controls and navigation elements — like tab bars and sidebars — that floats above the content layer, establishing a clear visual hierarchy between functional elements and content. Liquid Glass allows content to scroll and peek through from beneath these elements to give the interface a sense of dynamism and depth, all while maintaining legibility for controls and navigation.

![An image of four intersecting shapes of Liquid Glass material, floating above a neutral background. The shapes act as lenses in the areas where they overlap, bending and shading the surfaces beneath them. They cast shadows on the background layer that show through the material and cause it to subtly darken in patterns matching the shapes above.](https://docs-assets.developer.apple.com/published/6574b2aaed7c092743a5db7cffd05ec0/materials-liquid-glass-overview%402x.png)

**Don’t use Liquid Glass in the content layer.** Liquid Glass works best when it provides a clear distinction between interactive elements and content, and including it in the content layer can result in unnecessary complexity and a confusing visual hierarchy. Instead, use [standard materials](https://developer.apple.com/design/human-interface-guidelines/materials#Standard-materials) for elements in the content layer, such as app backgrounds. An exception to this is for controls in the content layer with a transient interactive element like [sliders](https://developer.apple.com/design/human-interface-guidelines/sliders) and [toggles](https://developer.apple.com/design/human-interface-guidelines/toggles); in these cases, the element takes on a Liquid Glass appearance to emphasize its interactivity when a person activates it.

**Use Liquid Glass effects sparingly.** Standard components from system frameworks pick up the appearance and behavior of this material automatically. If you apply Liquid Glass effects to a custom control, do so sparingly. Liquid Glass seeks to bring attention to the underlying content, and overusing this material in multiple custom controls can provide a subpar user experience by distracting from that content. Limit these effects to the most important functional elements in your app. For developer guidance, see [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views).

## Standard materials

Use standard materials and effects — such as [blur](https://developer.apple.com/documentation/UIKit/UIBlurEffect), [vibrancy](https://developer.apple.com/documentation/UIKit/UIVibrancyEffect), and [blending modes](https://developer.apple.com/documentation/AppKit/NSVisualEffectView/BlendingMode-swift.enum) — to convey a sense of structure in the content beneath Liquid Glass.

**Choose materials and effects based on semantic meaning and recommended usage.** Avoid selecting a material or effect based on the apparent color it imparts to your interface, because system settings can change its appearance and behavior. Instead, match the material or vibrancy style to your specific use case.

**Help ensure legibility by using vibrant colors on top of materials.** When you use system-defined vibrant colors, you don’t need to worry about colors seeming too dark, bright, saturated, or low contrast in different contexts. Regardless of the material you choose, use vibrant colors on top of it. For guidance, see [System colors](https://developer.apple.com/design/human-interface-guidelines/color#System-colors).

**Consider contrast and visual separation when choosing a material to combine with blur and vibrancy effects.** For example, consider that:

- Thicker materials, which are more opaque, can provide better contrast for text and other elements with fine features.
- Thinner materials, which are more translucent, can help people retain their context by providing a visible reminder of the content that’s in the background.

For developer guidance, see [`Material`](https://developer.apple.com/documentation/SwiftUI/Material).

## Platform considerations

### iOS, iPadOS

iOS and iPadOS define vibrant colors for labels, fills, and separators that are specifically designed to work with each material.

Labels and fills both have several levels of vibrancy; separators have one level. The name of a level indicates the relative amount of contrast between an element and the background: The default level has the highest contrast, whereas quaternary (when it exists) has the lowest contrast.

![An illustration of a separator with a translucent background material. The separator uses vibrant color and is clearly visible against the background material.](https://docs-assets.developer.apple.com/published/5122a5daa7c0f6907111e19239355ca1/materials-separator-vibrancy~dark%402x.png)

Separator vibrancy

Except for quaternary, you can use the following vibrancy values for labels on any material. In general, avoid using quaternary on top of the [`thin`](https://developer.apple.com/documentation/SwiftUI/Material/thin) and [`ultraThin`](https://developer.apple.com/documentation/SwiftUI/Material/ultraThin) materials, because the contrast is too low.

- [`UIVibrancyEffectStyle.label`](https://developer.apple.com/documentation/UIKit/UIVibrancyEffectStyle/label) (default)
- [`UIVibrancyEffectStyle.secondaryLabel`](https://developer.apple.com/documentation/UIKit/UIVibrancyEffectStyle/secondaryLabel)
- [`UIVibrancyEffectStyle.tertiaryLabel`](https://developer.apple.com/documentation/UIKit/UIVibrancyEffectStyle/tertiaryLabel)
- [`UIVibrancyEffectStyle.quaternaryLabel`](https://developer.apple.com/documentation/UIKit/UIVibrancyEffectStyle/quaternaryLabel)

You can use the following vibrancy values for fills on all materials.

- [`UIVibrancyEffectStyle.fill`](https://developer.apple.com/documentation/UIKit/UIVibrancyEffectStyle/fill) (default)
- [`UIVibrancyEffectStyle.secondaryFill`](https://developer.apple.com/documentation/UIKit/UIVibrancyEffectStyle/secondaryFill)
- [`UIVibrancyEffectStyle.tertiaryFill`](https://developer.apple.com/documentation/UIKit/UIVibrancyEffectStyle/tertiaryFill)

The system provides a single, default vibrancy value for a [separator](https://developer.apple.com/documentation/UIKit/UIVibrancyEffectStyle/separator), which works well on all materials.

### macOS

macOS provides several standard materials with designated purposes, and vibrant versions of all [system colors](https://developer.apple.com/design/human-interface-guidelines/color#Specifications). For developer guidance, see [`NSVisualEffectView.Material`](https://developer.apple.com/documentation/AppKit/NSVisualEffectView/Material-swift.enum).

**Choose when to allow vibrancy in custom views and controls.** Depending on configuration and system settings, system views and controls use vibrancy to make foreground content stand out against any background. Test your interface in a variety of contexts to discover when vibrancy enhances the appearance and improves communication.

**Choose a background blending mode that complements your interface design.** macOS defines two modes that blend background content: behind window and within window. For developer guidance, see [`NSVisualEffectView.BlendingMode`](https://developer.apple.com/documentation/AppKit/NSVisualEffectView/BlendingMode-swift.enum).

### tvOS

**Use thinner, translucent materials to elevate content and make it feel fresh.** Thicker materials tend to hide shadows, reducing depth and making it harder to distinguish content clearly. You might consider using thicker materials if you want to evoke a heavier feeling or suggest that the content is older.

![An illustration of a tvOS screen with Control Center visible on the right. Control Center uses a thicker material as its main background, with thinner materials for the control buttons and vibrant label colors for the button icons and text.](https://docs-assets.developer.apple.com/published/ac7f329c46dba8f73a814acdf3b72392/tvos-materials-in-control-center~dark%402x.png)

For example, consider using standard materials in the following ways:

| Material | Recommended for |
| --- | --- |
| [`ultraThin`](https://developer.apple.com/documentation/SwiftUI/Material/ultraThin) | Full-screen views that require a light color scheme |
| [`thin`](https://developer.apple.com/documentation/SwiftUI/Material/thin) | Overlay views that partially obscure onscreen content and require a light color scheme |
| [`regular`](https://developer.apple.com/documentation/SwiftUI/Material/regular) | Overlay views that partially obscure onscreen content |
| [`thick`](https://developer.apple.com/documentation/SwiftUI/Material/thick) | Overlay views that partially obscure onscreen content and require a dark color scheme |
| [`ultraThick`](https://developer.apple.com/documentation/SwiftUI/Material/ultraThick) | Full-screen views that require a dark color scheme |

You can also use the [prominent](https://developer.apple.com/documentation/uikit/uiblureffect/style/prominent) blur effect for adaptable, full-screen backgrounds in your tvOS app.

### visionOS

In visionOS, windows generally use an unmodifiable system-defined material called *glass* that helps people stay grounded by letting light, the current Environment, virtual content, and objects in people’s surroundings show through. Glass is an adaptive material that limits the range of background color information so a window can continue to provide contrast for app content while becoming brighter or darker depending on people’s physical surroundings and other virtual content.

<video width="960"><source src="https://docs-assets.developer.apple.com/published/867bebad45a7ed782893751ddcc6a83d/visionos-glass-material-transition.mp4"></video> [Play](https://developer.apple.com/design/human-interface-guidelines/#)

**Avoid using opaque colors in a window.** Areas of opacity can block people’s view, making them feel constricted and reducing their awareness of the virtual and physical objects around them.

![An illustration of a field of view in visionOS with a window in the center. The window has a translucent material background that allows its surroundings to pass through.](https://docs-assets.developer.apple.com/published/d86b4432acb90ca468f934187d4d68e9/materials-visionos-glass-window%402x.png)

![A checkmark in a circle to indicate correct usage](https://docs-assets.developer.apple.com/published/88662da92338267bb64cd2275c84e484/checkmark%402x.png)

![An illustration of a field of view in visionOS with a window in the center. The window has an opaque background that obstructs its surroundings.](https://docs-assets.developer.apple.com/published/972c2f9b1bc593b3e5af3b0eb2dba297/materials-visionos-opaque-window-incorrect%402x.png)

![An X in a circle to indicate incorrect usage](https://docs-assets.developer.apple.com/published/209f6f0fc8ad99d9bf59e12d82d06584/crossout%402x.png)

**If necessary, choose materials that help you create visual separations or indicate interactivity in your app.** If you need to create a custom component, you may need to specify a system material for it. Use the following examples for guidance.

- The [`thin`](https://developer.apple.com/documentation/SwiftUI/Material/thin) material brings attention to interactive elements like buttons and selected items.
- The [`regular`](https://developer.apple.com/documentation/SwiftUI/Material/regular) material can help you visually separate sections of your app, like a sidebar or a grouped table view.
- The [`thick`](https://developer.apple.com/documentation/SwiftUI/Material/thick) material lets you create a dark element that remains visually distinct when it’s on top of an area that uses a `regular` background.

![An illustration of a field of view in visionOS with a window in the center. The window is composed of a sidebar on the left and a content area on the right, with a text field at the top and a button in the lower-right corner. The sidebar uses regular material, while the text field uses thick material and the button uses thin material.](https://docs-assets.developer.apple.com/published/1d2fb4275fe81d54b53fb8f526761e23/visionos-materials-window-example~dark%402x.png)

To ensure foreground content remains legible when it displays on top of a material, visionOS applies vibrancy to text, symbols, and fills. Vibrancy enhances the sense of depth by pulling light and color forward from both virtual and physical surroundings.

visionOS defines three vibrancy values that help you communicate a hierarchy of text, symbols, and fills.

- Use [`UIVibrancyEffectStyle.label`](https://developer.apple.com/documentation/UIKit/UIVibrancyEffectStyle/label) for standard text.
- Use [`UIVibrancyEffectStyle.secondaryLabel`](https://developer.apple.com/documentation/UIKit/UIVibrancyEffectStyle/secondaryLabel) for descriptive text like footnotes and subtitles.
- Use [`UIVibrancyEffectStyle.tertiaryLabel`](https://developer.apple.com/documentation/UIKit/UIVibrancyEffectStyle/tertiaryLabel) for inactive elements, and only when text doesn’t need high legibility.

![An illustration of a Share button with a translucent background material and a symbol. The symbol uses the default vibrant label color and has very high contrast against the background material.](https://docs-assets.developer.apple.com/published/a0f8cdc57247da72d9bd0a69a34f7848/materials-visionos-label-vibrant-primary%402x.png)

`label`

![An illustration of a Share button with a translucent background material and a symbol. The symbol uses the secondary vibrant label color and has high contrast against the background material.](https://docs-assets.developer.apple.com/published/e5bf4c86df0f63fb98866dc1a6e4edd1/materials-visionos-label-vibrant-secondary%402x.png)

secondary Label

![An illustration of a Share button with a translucent background material and a symbol. The symbol uses the tertiary vibrant label color and has muted contrast against the background material.](https://docs-assets.developer.apple.com/published/724f64dcfd974e4dd26700824544d735/materials-visionos-label-vibrant-tertiary%402x.png)

tertiary Label

### watchOS

**Use materials to provide context in a full-screen modal view.** Because full-screen modal views are common in watchOS, the contrast provided by material layers can help orient people in your app and distinguish controls and system elements from other content. Avoid removing or replacing material backgrounds for modal sheets when they’re provided by default.

![An illustration of a modal view in watchOS for selecting an audio output destination. The modal completely covers the screen with a transparent material, and uses thinner materials for its buttons along with vibrant label text.](https://docs-assets.developer.apple.com/published/be1600b130fecbe1c41081219a450e31/watchos-modal-view-material-background%402x.png)

## Resources

[Color](https://developer.apple.com/design/human-interface-guidelines/color)

[Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)

[Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode)

#### Developer documentation

[Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)

[`glassEffect(_:in:)`](https://developer.apple.com/documentation/SwiftUI/View/glassEffect\(_:in:\))

[`Material`](https://developer.apple.com/documentation/SwiftUI/Material) — SwiftUI

[`UIVisualEffectView`](https://developer.apple.com/documentation/UIKit/UIVisualEffectView) — UIKit

[`NSVisualEffectView`](https://developer.apple.com/documentation/AppKit/NSVisualEffectView) — AppKit

#### Videos

## Change log

| Date | Changes |
| --- | --- |
| June 9, 2025 | Added guidance for Liquid Glass. |
| August 6, 2024 | Added platform-specific art. |
| December 5, 2023 | Updated descriptions of the various material types, and clarified terms related to vibrancy and material thickness. |
| June 21, 2023 | Updated to include guidance for visionOS. |
| June 5, 2023 | Added guidance on using materials to provide context and orientation in watchOS apps. |

Current page is Materials