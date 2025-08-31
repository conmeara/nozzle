---
title: "Color"
source: "https://developer.apple.com/design/human-interface-guidelines/color"
author:
  - "[[Apple Developer Documentation]]"
published:
created: 2025-08-31
description: "Judicious use of color can enhance communication, evoke your brand, provide visual continuity, communicate status and feedback, and help people understand information."
tags:
  - "clippings"
---
[Skip Navigation](https://developer.apple.com/design/human-interface-guidelines/#app-main)

Judicious use of color can enhance communication, evoke your brand, provide visual continuity, communicate status and feedback, and help people understand information.

![A sketch of a paint palette, suggesting the use of color. The image is overlaid with rectangular and circular grid lines and is tinted yellow to subtly reflect the yellow in the original six-color Apple logo.](https://docs-assets.developer.apple.com/published/399ee993cc15dc067a0cd53257163ac3/foundations-color-intro~dark%402x.png)

The system defines colors that look good on various backgrounds and appearance modes, and can automatically adapt to vibrancy and accessibility settings. Using system colors is a convenient way to make your experience feel at home on the device.

You may also want to use custom colors to enhance the visual experience of your app or game and express its unique personality. The following guidelines can help you use color in ways that people appreciate, regardless of whether you use system-defined or custom colors.

## Best practices

**Avoid using the same color to mean different things.** Use color consistently throughout your interface, especially when you use it to help communicate information like status or interactivity. For example, if you use your brand color to indicate that a borderless button is interactive, using the same or similar color to stylize noninteractive text is confusing.

**Make sure your app’s colors work well in both light and dark contexts.** iOS, iPadOS, macOS, and tvOS offer both light and [dark](https://developer.apple.com/design/human-interface-guidelines/dark-mode) appearance settings. System colors vary subtly depending on the system appearance, adjusting to ensure proper color differentiation and contrast for text, symbols, and other elements. With the Increase Contrast setting turned on, the color differences become far more apparent. If you use a custom color, supply light and dark variants, and an increased contrast option for each variant.

**Test your app’s color scheme under a variety of lighting conditions.** Colors can look different when you view your app outside on a sunny day or in dim light. In bright surroundings, colors look darker and more muted. In dark environments, colors appear bright and saturated. In visionOS, colors can look different depending on the colors of a wall or object in a person’s physical surroundings and how it reflects light. Adjust app colors to provide an optimal viewing experience in the majority of use cases.

**Test your app on different devices.** For example, the True Tone display — available on certain iPhone, iPad, and Mac models — uses ambient light sensors to automatically adjust the white point of the display to adapt to the lighting conditions of the current environment. Apps that primarily support reading, photos, video, and gaming can strengthen or weaken this effect by specifying a white point adaptivity style (for developer guidance, see [`UIWhitePointAdaptivityStyle`](https://developer.apple.com/documentation/BundleResources/Information-Property-List/UIWhitePointAdaptivityStyle)). Test tvOS apps on multiple brands of HD and 4K TVs, and with different display settings. You can also test the appearance of your app using different color profiles on a Mac — such as P3 and Standard RGB (sRGB) — by choosing a profile in System Settings > Displays. For guidance, see [Color management](https://developer.apple.com/design/human-interface-guidelines/color#Color-management).

**Consider how artwork and translucency affect nearby colors.** Variations in artwork sometimes warrant changes to nearby colors to maintain visual continuity and prevent interface elements from becoming overpowering or underwhelming. Maps, for example, displays a light color scheme when in map mode but switches to a dark color scheme when in satellite mode. Colors can also appear different when placed behind or applied to a translucent element like a toolbar.

**If your app lets people choose colors, prefer system-provided color controls where available.** Using built-in color pickers provides a consistent user experience, in addition to letting people save a set of colors they can access from any app. For developer guidance, see [`ColorPicker`](https://developer.apple.com/documentation/SwiftUI/ColorPicker).

## Inclusive color

**Avoid relying solely on color to differentiate between objects, indicate interactivity, or communicate essential information.** When you use color to convey information, be sure to provide the same information in alternative ways so people with color blindness or other visual disabilities can understand it. For example, you can use text labels or glyph shapes to identify objects or states.

**Avoid using colors that make it hard to perceive content in your app.** For example, insufficient contrast can cause icons and text to blend with the background and make content hard to read, and people who are color blind might not be able to distinguish some color combinations. For guidance, see [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility).

**Consider how the colors you use might be perceived in other countries and cultures.** For example, red communicates danger in some cultures, but has positive connotations in other cultures. Make sure the colors in your app send the message you intend.

## System colors

**Avoid hard-coding system color values in your app.** Documented color values are for your reference during the app design process. The actual color values may fluctuate from release to release, based on a variety of environmental variables. Use APIs like [`Color`](https://developer.apple.com/documentation/SwiftUI/Color) to apply system colors.

iOS, iPadOS, macOS, and visionOS also define sets of *dynamic system colors* that match the color schemes of standard UI components and automatically adapt to both light and dark contexts. Each dynamic color is semantically defined by its purpose, rather than its appearance or color values. For example, some colors represent view backgrounds at different levels of hierarchy and other colors represent foreground content, such as labels, links, and separators.

**Avoid redefining the semantic meanings of dynamic system colors.** To ensure a consistent experience and ensure your interface looks great when the appearance of the platform changes, use dynamic system colors as intended. For example, don’t use the [separator](https://developer.apple.com/documentation/uikit/uicolor/separator) color as a text color, or [secondary text label](https://developer.apple.com/documentation/uikit/uicolor/secondarylabel) color as a background color.

## Liquid Glass color

For smaller elements like toolbars and tab bars, the system can adapt [Liquid Glass](https://developer.apple.com/design/human-interface-guidelines/materials#Liquid-Glass) between a light and dark appearance in response to the underlying content. Symbols and text on these elements follow a monochromatic color scheme, becoming darker when the underlying content is light, and lighter when it’s dark.

Liquid Glass appears more opaque in larger elements like sidebars to preserve legibility over complex backgrounds and accommodate richer content on the material’s surface.

![An image of three intersecting circles of Liquid Glass material, one tinted red, one tinted blue, and one tinted green, floating above a neutral background. The circles act as lenses in the areas where they overlap, bending and tinting the surfaces beneath them. They cast shadows on the background layer that show through the material and cause it to subtly darken in a diffuse ring pattern.](https://docs-assets.developer.apple.com/published/48ea4986609ac50385955b3d9ac9d3ec/colors-tinted-liquid-glass-overview%402x.png)

**Use color sparingly in Liquid Glass.** To reduce visual noise, limit the amount of color you apply to the material, and to symbols or text on the material. If you apply color, reserve it for elements that truly benefit from emphasis, such as status indicators or key actions. For example, the system applies tint color to the material backing in prominent buttons — such as the Done button — to draw attention and elevate their visual prominence.

![A screenshot of the top half of an iPhone app that shows a toolbar with several buttons. All of the buttons in the toolbar use a blue tint color for their Liquid Glass material backing.](https://docs-assets.developer.apple.com/published/2585d7169a94e0dd7edebcf18e1c10d7/colors-liquid-glass-usage-incorrect~dark%402x.png)

![An X in a circle to indicate incorrect usage.](https://docs-assets.developer.apple.com/published/209f6f0fc8ad99d9bf59e12d82d06584/crossout%402x.png)

![A screenshot of the top half of an iPhone app that shows a toolbar with several buttons. Only the Done button in the toolbar uses a blue tint color for its Liquid Glass material backing.](https://docs-assets.developer.apple.com/published/b040c3a7fe299b6d99e2ab18bdb87a7f/colors-liquid-glass-usage-correct~dark%402x.png)

![A checkmark in a circle to indicate correct usage.](https://docs-assets.developer.apple.com/published/88662da92338267bb64cd2275c84e484/checkmark%402x.png)

**Consider using color in the content layer to evoke your brand.** If your app feels visually muted or lacks sufficient brand emphasis, consider adjusting the color palette in your content layer, such as adding a colorful header to the scrollable content. This approach allows your app to continue expressing its unique personality without distracting from content. Refrain from adding color throughout Liquid Glass solely to evoke your brand.

![A screenshot of the top half of an iPhone app with a uniform blank appearance throughout the content layer, with the toolbar the same color as other content areas.](https://docs-assets.developer.apple.com/published/97f2e469ab86015caba35d9c37778470/color-empty-background-glass-buttons~dark%402x.png)

Liquid Glass elements over a simple background.

![A screenshot of the top half of an iPhone app that shows a colorful teal header in the area of the content layer beneath the toolbar.](https://docs-assets.developer.apple.com/published/0354aa24c2fd1cab0d946e67e527e50b/color-filled-background-glass-buttons~dark%402x.png)

Color in the content layer can help highlight your brand.

## Color management

A *color space* represents the colors in a *color model* like RGB or CMYK. Common color spaces — sometimes called *gamuts* — are sRGB and Display P3.

![Diagram showing the colors included in the sRGB space, compared to the larger number of colors included in the P3 color space.](https://docs-assets.developer.apple.com/published/149433f818fd3b7afbda1949040aad43/color-graphic-wide-color~dark%402x.png)

A *color profile* describes the colors in a color space using, for example, mathematical formulas or tables of data that map colors to numerical representations. An image embeds its color profile so that a device can interpret the image’s colors correctly and reproduce them on a display.

**Apply color profiles to your images.** Color profiles help ensure that your app’s colors appear as intended on different displays. The sRGB color space produces accurate colors on most displays.

**Use wide color to enhance the visual experience on compatible displays.** Wide color displays support a P3 color space, which can produce richer, more saturated colors than sRGB. As a result, photos and videos that use wide color are more lifelike, and visual data and status indicators that use wide color can be more meaningful. When appropriate, use the Display P3 color profile at 16 bits per pixel (per channel) and export images in PNG format. Note that you need to use a wide color display to design wide color images and select P3 colors.

**Provide color space–specific image and color variations if necessary.** In general, P3 colors and images appear fine on sRGB displays. Occasionally, it may be hard to distinguish two very similar P3 colors when viewing them on an sRGB display. Gradients that use P3 colors can also sometimes appear clipped on sRGB displays. To avoid these issues and to ensure visual fidelity on both wide color and sRGB displays, you can use the asset catalog of your Xcode project to provide different versions of images and colors for each color space.

## Platform considerations

### iOS, iPadOS

iOS defines two sets of dynamic background colors — *system* and *grouped* — each of which contains primary, secondary, and tertiary variants that help you convey a hierarchy of information. In general, use the grouped background colors ([`systemGroupedBackground`](https://developer.apple.com/documentation/UIKit/UIColor/systemGroupedBackground), [`secondarySystemGroupedBackground`](https://developer.apple.com/documentation/UIKit/UIColor/secondarySystemGroupedBackground), and [`tertiarySystemGroupedBackground`](https://developer.apple.com/documentation/UIKit/UIColor/tertiarySystemGroupedBackground)) when you have a grouped table view; otherwise, use the system set of background colors ([`systemBackground`](https://developer.apple.com/documentation/UIKit/UIColor/systemBackground), [`secondarySystemBackground`](https://developer.apple.com/documentation/UIKit/UIColor/secondarySystemBackground), and [`tertiarySystemBackground`](https://developer.apple.com/documentation/UIKit/UIColor/tertiarySystemBackground)).

With both sets of background colors, you generally use the variants to indicate hierarchy in the following ways:

- Primary for the overall view
- Secondary for grouping content or elements within the overall view
- Tertiary for grouping content or elements within secondary elements

For foreground content, iOS defines the following dynamic colors:

| Color | Use for… | UIKit API |
| --- | --- | --- |
| Label | A text label that contains primary content. | [`label`](https://developer.apple.com/documentation/UIKit/UIColor/label) |
| Secondary label | A text label that contains secondary content. | [`secondaryLabel`](https://developer.apple.com/documentation/UIKit/UIColor/secondaryLabel) |
| Tertiary label | A text label that contains tertiary content. | [`tertiaryLabel`](https://developer.apple.com/documentation/UIKit/UIColor/tertiaryLabel) |
| Quaternary label | A text label that contains quaternary content. | [`quaternaryLabel`](https://developer.apple.com/documentation/UIKit/UIColor/quaternaryLabel) |
| Placeholder text | Placeholder text in controls or text views. | [`placeholderText`](https://developer.apple.com/documentation/UIKit/UIColor/placeholderText) |
| Separator | A separator that allows some underlying content to be visible. | [`separator`](https://developer.apple.com/documentation/UIKit/UIColor/separator) |
| Opaque separator | A separator that doesn’t allow any underlying content to be visible. | [`opaqueSeparator`](https://developer.apple.com/documentation/UIKit/UIColor/opaqueSeparator) |
| Link | Text that functions as a link. | [`link`](https://developer.apple.com/documentation/UIKit/UIColor/link) |

### macOS

macOS defines the following dynamic system colors (you can also view them in the Developer palette of the standard Color panel):

| Color | Use for… | AppKit API |
| --- | --- | --- |
| Alternate selected control text color | The text on a selected surface in a list or table. | [`alternateSelectedControlTextColor`](https://developer.apple.com/documentation/AppKit/NSColor/alternateSelectedControlTextColor) |
| Alternating content background colors | The backgrounds of alternating rows or columns in a list, table, or collection view. | [`alternatingContentBackgroundColors`](https://developer.apple.com/documentation/AppKit/NSColor/alternatingContentBackgroundColors) |
| Control accent | The accent color people select in System Settings. | [`controlAccentColor`](https://developer.apple.com/documentation/AppKit/NSColor/controlAccentColor) |
| Control background color | The background of a large interface element, such as a browser or table. | [`controlBackgroundColor`](https://developer.apple.com/documentation/AppKit/NSColor/controlBackgroundColor) |
| Control color | The surface of a control. | [`controlColor`](https://developer.apple.com/documentation/AppKit/NSColor/controlColor) |
| Control text color | The text of a control that is available. | [`controlTextColor`](https://developer.apple.com/documentation/AppKit/NSColor/controlTextColor) |
| Current control tint | The system-defined control tint. | [`currentControlTint`](https://developer.apple.com/documentation/AppKit/NSColor/currentControlTint) |
| Unavailable control text color | The text of a control that’s unavailable. | [`disabledControlTextColor`](https://developer.apple.com/documentation/AppKit/NSColor/disabledControlTextColor) |
| Find highlight color | The color of a find indicator. | [`findHighlightColor`](https://developer.apple.com/documentation/AppKit/NSColor/findHighlightColor) |
| Grid color | The gridlines of an interface element, such as a table. | [`gridColor`](https://developer.apple.com/documentation/AppKit/NSColor/gridColor) |
| Header text color | The text of a header cell in a table. | [`headerTextColor`](https://developer.apple.com/documentation/AppKit/NSColor/headerTextColor) |
| Highlight color | The virtual light source onscreen. | [`highlightColor`](https://developer.apple.com/documentation/AppKit/NSColor/highlightColor) |
| Keyboard focus indicator color | The ring that appears around the currently focused control when using the keyboard for interface navigation. | [`keyboardFocusIndicatorColor`](https://developer.apple.com/documentation/AppKit/NSColor/keyboardFocusIndicatorColor) |
| Label color | The text of a label containing primary content. | [`labelColor`](https://developer.apple.com/documentation/AppKit/NSColor/labelColor) |
| Link color | A link to other content. | [`linkColor`](https://developer.apple.com/documentation/AppKit/NSColor/linkColor) |
| Placeholder text color | A placeholder string in a control or text view. | [`placeholderTextColor`](https://developer.apple.com/documentation/AppKit/NSColor/placeholderTextColor) |
| Quaternary label color | The text of a label of lesser importance than a tertiary label, such as watermark text. | [`quaternaryLabelColor`](https://developer.apple.com/documentation/AppKit/NSColor/quaternaryLabelColor) |
| Secondary label color | The text of a label of lesser importance than a primary label, such as a label used to represent a subheading or additional information. | [`secondaryLabelColor`](https://developer.apple.com/documentation/AppKit/NSColor/secondaryLabelColor) |
| Selected content background color | The background for selected content in a key window or view. | [`selectedContentBackgroundColor`](https://developer.apple.com/documentation/AppKit/NSColor/selectedContentBackgroundColor) |
| Selected control color | The surface of a selected control. | [`selectedControlColor`](https://developer.apple.com/documentation/AppKit/NSColor/selectedControlColor) |
| Selected control text color | The text of a selected control. | [`selectedControlTextColor`](https://developer.apple.com/documentation/AppKit/NSColor/selectedControlTextColor) |
| Selected menu item text color | The text of a selected menu. | [`selectedMenuItemTextColor`](https://developer.apple.com/documentation/AppKit/NSColor/selectedMenuItemTextColor) |
| Selected text background color | The background of selected text. | [`selectedTextBackgroundColor`](https://developer.apple.com/documentation/AppKit/NSColor/selectedTextBackgroundColor) |
| Selected text color | The color for selected text. | [`selectedTextColor`](https://developer.apple.com/documentation/AppKit/NSColor/selectedTextColor) |
| Separator color | A separator between different sections of content. | [`separatorColor`](https://developer.apple.com/documentation/AppKit/NSColor/separatorColor) |
| Shadow color | The virtual shadow cast by a raised object onscreen. | [`shadowColor`](https://developer.apple.com/documentation/AppKit/NSColor/shadowColor) |
| Tertiary label color | The text of a label of lesser importance than a secondary label. | [`tertiaryLabelColor`](https://developer.apple.com/documentation/AppKit/NSColor/tertiaryLabelColor) |
| Text background color | The background color behind text. | [`textBackgroundColor`](https://developer.apple.com/documentation/AppKit/NSColor/textBackgroundColor) |
| Text color | The text in a document. | [`textColor`](https://developer.apple.com/documentation/AppKit/NSColor/textColor) |
| Under page background color | The background behind a document’s content. | [`underPageBackgroundColor`](https://developer.apple.com/documentation/AppKit/NSColor/underPageBackgroundColor) |
| Unemphasized selected content background color | The selected content in a non-key window or view. | [`unemphasizedSelectedContentBackgroundColor`](https://developer.apple.com/documentation/AppKit/NSColor/unemphasizedSelectedContentBackgroundColor) |
| Unemphasized selected text background color | A background for selected text in a non-key window or view. | [`unemphasizedSelectedTextBackgroundColor`](https://developer.apple.com/documentation/AppKit/NSColor/unemphasizedSelectedTextBackgroundColor) |
| Unemphasized selected text color | Selected text in a non-key window or view. | [`unemphasizedSelectedTextColor`](https://developer.apple.com/documentation/AppKit/NSColor/unemphasizedSelectedTextColor) |
| Window background color | The background of a window. | [`windowBackgroundColor`](https://developer.apple.com/documentation/AppKit/NSColor/windowBackgroundColor) |
| Window frame text color | The text in the window’s title bar area. | [`windowFrameTextColor`](https://developer.apple.com/documentation/AppKit/NSColor/windowFrameTextColor) |

#### App accent colors

Beginning in macOS 11, you can specify an *accent color* to customize the appearance of your app’s buttons, selection highlighting, and sidebar icons. The system applies your accent color when the current value in General > Accent color settings is *multicolor*.

![A screenshot of the accent color picker in the System Settings app.](https://docs-assets.developer.apple.com/published/9904b9acd3c43cc6cbda49bdb4473299/colors-accent-colors-picker-multicolor~dark%402x.png)

If people set their accent color setting to a value other than multicolor, the system applies their chosen color to the relevant items throughout your app, replacing your accent color. The exception is a sidebar icon that uses a fixed color you specify. Because a fixed-color sidebar icon uses a specific color to provide meaning, the system doesn’t override its color when people change the value of accent color settings. For guidance, see [Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars).

### tvOS

**Consider choosing a limited color palette that coordinates with your app logo.** Subtle use of color can help you communicate your brand while deferring to the content.

**Avoid using only color to indicate focus.** Subtle scaling and responsive animation are the primary ways to denote interactivity when an element is in focus.

### visionOS

**Use color sparingly, especially on glass.** Standard visionOS windows typically use the system-defined glass [material](https://developer.apple.com/design/human-interface-guidelines/materials), which lets light and objects from people’s physical surroundings and their space show through. Because the colors in these physical and virtual objects are visible through the glass, they can affect the legibility of colorful app content in the window. Prefer using color in places where it can help call attention to important information or show the relationship between parts of the interface.

**Prefer using color in bold text and large areas.** Color in lightweight text or small areas can make them harder to see and understand.

**In a fully immersive experience, help people maintain visual comfort by keeping brightness levels balanced.** Although using high contrast can help direct people’s attention to important content, it can also cause visual discomfort if people’s eyes have adjusted to low light or darkness. Consider making content fully bright only when the rest of the visual context is also bright. For example, avoid displaying a bright object on a very dark or black background, especially if the object flashes or moves.

### watchOS

**Use background color to support existing content or supply additional information.** Background color can establish a sense of place and help people recognize key content. For example, in Activity, each infographic view for the Move, Exercise, and Stand Activity rings has a background that matches the color of the ring. Use background color when you have something to communicate, rather than as a solely visual flourish. Avoid using full-screen background color in views that are likely to remain onscreen for long periods of time, such as in a workout or audio-playing app.

**Recognize that people might prefer graphic complications to use tinted mode instead of full color.** The system can use a single color that’s based on the wearer’s selected color in a graphic complication’s images, gauges, and text. For guidance, see [Complications](https://developer.apple.com/design/human-interface-guidelines/complications).

## Specifications

### System colors

| Name | SwiftUI API | Default (light) | Default (dark) | Increased contrast (light) | Increased contrast (dark) |
| --- | --- | --- | --- | --- | --- |
| Red | [`red`](https://developer.apple.com/documentation/SwiftUI/Color/red) | ![R-255,G-56,B-60](https://docs-assets.developer.apple.com/published/5faf14474868d4473d9c720bbeb05168/colors-unified-red-light~dark%402x.png) | ![R-255,G-66,B-69](https://docs-assets.developer.apple.com/published/42db18c65807e9d9d705478ff2da168a/colors-unified-red-dark~dark%402x.png) | ![R-233,G-21,B-45](https://docs-assets.developer.apple.com/published/550b81ae10dc76869bf3bda9812ace09/colors-unified-accessible-red-light~dark%402x.png) | ![R-255,G-97,B-101](https://docs-assets.developer.apple.com/published/c9231fb3d221047819f4646aaee4b2de/colors-unified-accessible-red-dark~dark%402x.png) |
| Orange | [`orange`](https://developer.apple.com/documentation/SwiftUI/Color/orange) | ![R-255,G-141,B-40](https://docs-assets.developer.apple.com/published/9f113bce48fc72dc6ca466ad9cdf0f05/colors-unified-orange-light~dark%402x.png) | ![R-255,G-146,B-48](https://docs-assets.developer.apple.com/published/43486a6f9094ca1bd7076a9e707c87f7/colors-unified-orange-dark~dark%402x.png) | ![R-197,G-83,B-0](https://docs-assets.developer.apple.com/published/9204f66a0bb0fe3b2120c0db26b4635b/colors-unified-accessible-orange-light~dark%402x.png) | ![R-255,G-160,B-86](https://docs-assets.developer.apple.com/published/5b36b0f8fab6a36ffa0944d6faf216cc/colors-unified-accessible-orange-dark~dark%402x.png) |
| Yellow | [`yellow`](https://developer.apple.com/documentation/SwiftUI/Color/yellow) | ![R-255,G-204,B-0](https://docs-assets.developer.apple.com/published/197fb92a719822d951c8069c1e9f59c3/colors-unified-yellow-light~dark%402x.png) | ![R-255,G-214,B-0](https://docs-assets.developer.apple.com/published/52cccc30652d2fbb806ff41d88bdd56f/colors-unified-yellow-dark~dark%402x.png) | ![R-161,G-106,B-0](https://docs-assets.developer.apple.com/published/69a05ae18e1f69e1d3f2c54275182a7f/colors-unified-accessible-yellow-light~dark%402x.png) | ![R-254,G-223,B-67](https://docs-assets.developer.apple.com/published/6bb1f4620afc521953556213cb891487/colors-unified-accessible-yellow-dark~dark%402x.png) |
| Green | [`green`](https://developer.apple.com/documentation/SwiftUI/Color/green) | ![R-52,G-199,B-89](https://docs-assets.developer.apple.com/published/b7fa96f649da33c239d3b825d5c6fd42/colors-unified-green-light~dark%402x.png) | ![R-48,G-209,B-88](https://docs-assets.developer.apple.com/published/f8a83fc5d825c4a9e4f1d9813520053e/colors-unified-green-dark~dark%402x.png) | ![R-0,G-137,B-50](https://docs-assets.developer.apple.com/published/b90190fdd5be94345d7501933ba44e68/colors-unified-accessible-green-light~dark%402x.png) | ![R-74,G-217,B-104](https://docs-assets.developer.apple.com/published/4147a24638f1d3e22f25dde5b20bb548/colors-unified-accessible-green-dark~dark%402x.png) |
| Mint | [`mint`](https://developer.apple.com/documentation/SwiftUI/Color/mint) | ![R-0,G-200,B-179](https://docs-assets.developer.apple.com/published/fb878152db5857031038f175540f05ac/colors-unified-mint-light~dark%402x.png) | ![R-0,G-218,B-195](https://docs-assets.developer.apple.com/published/1b118b84eab4b15eee2579ea63c40ffc/colors-unified-mint-dark~dark%402x.png) | ![R-0,G-133,B-117](https://docs-assets.developer.apple.com/published/1040c03509c4025ee26a0bf9791e3b1e/colors-unified-accessible-mint-light~dark%402x.png) | ![R-84,G-223,B-203](https://docs-assets.developer.apple.com/published/03d932a81c8c8a36f5bf02fd77aceb20/colors-unified-accessible-mint-dark~dark%402x.png) |
| Teal | [`teal`](https://developer.apple.com/documentation/SwiftUI/Color/teal) | ![R-0,G-195,B-208](https://docs-assets.developer.apple.com/published/48fcae45068a0fe4c2a2d63f5c351970/colors-unified-teal-light~dark%402x.png) | ![R-0,G-210,B-224](https://docs-assets.developer.apple.com/published/86c0f6289b89d95575543329e6ed4e6a/colors-unified-teal-dark~dark%402x.png) | ![R-0,G-129,B-152](https://docs-assets.developer.apple.com/published/bec0729dd11729d4824251e4216c6f48/colors-unified-accessible-teal-light~dark%402x.png) | ![R-59,G-221,B-236](https://docs-assets.developer.apple.com/published/2363a49f5d3548979348e0912820d723/colors-unified-accessible-teal-dark~dark%402x.png) |
| Cyan | [`cyan`](https://developer.apple.com/documentation/SwiftUI/Color/cyan) | ![R-0,G-192,B-232](https://docs-assets.developer.apple.com/published/9de8bc6d14b46c36591b618762c2c641/colors-unified-cyan-light~dark%402x.png) | ![R-60,G-211,B-254](https://docs-assets.developer.apple.com/published/788402cbafa6f1644a3a092b0bc32fbd/colors-unified-cyan-dark~dark%402x.png) | ![R-0,G-126,B-174](https://docs-assets.developer.apple.com/published/0bbe8e2745424395e5d541426c12ca5a/colors-unified-accessible-cyan-light~dark%402x.png) | ![R-109,G-217,B-255](https://docs-assets.developer.apple.com/published/e7b37c5c344729946728c72a412fa7c4/colors-unified-accessible-cyan-dark~dark%402x.png) |
| Blue | [`blue`](https://developer.apple.com/documentation/SwiftUI/Color/blue) | ![R-0,G-136,B-255](https://docs-assets.developer.apple.com/published/351df342c9792a9924ca098f796fc82a/colors-unified-blue-light~dark%402x.png) | ![R-0,G-145,B-255](https://docs-assets.developer.apple.com/published/0f789f1355e3f6ba1199a17211c35f5c/colors-unified-blue-dark~dark%402x.png) | ![R-30,G-110,B-244](https://docs-assets.developer.apple.com/published/f5dff3297aeb38f035421ff2860cae15/colors-unified-accessible-blue-light~dark%402x.png) | ![R-92,G-184,B-255](https://docs-assets.developer.apple.com/published/f28b5b18d9fc9e1ae8c4930a8dd1b055/colors-unified-accessible-blue-dark~dark%402x.png) |
| Indigo | [`indigo`](https://developer.apple.com/documentation/SwiftUI/Color/indigo) | ![R-97,G-85,B-245](https://docs-assets.developer.apple.com/published/e62f44b7aeed4482e99d58791fc8a0e9/colors-unified-indigo-light~dark%402x.png) | ![R-107,G-93,B-255](https://docs-assets.developer.apple.com/published/087af20d3be96722b9e310dae0b35531/colors-unified-indigo-dark~dark%402x.png) | ![R-86,G-74,B-222](https://docs-assets.developer.apple.com/published/6377c830715ed85a8028ad086c9dd51f/colors-unified-accessible-indigo-light~dark%402x.png) | ![R-167,G-170,B-255](https://docs-assets.developer.apple.com/published/e0bce8448f5cfabacd6791c29d41fd59/colors-unified-accessible-indigo-dark~dark%402x.png) |
| Purple | [`purple`](https://developer.apple.com/documentation/SwiftUI/Color/purple) | ![R-203,G-48,B-224](https://docs-assets.developer.apple.com/published/d595b3ac24b517a72ddb5c3e1770c9e9/colors-unified-purple-light~dark%402x.png) | ![R-219,G-52,B-242](https://docs-assets.developer.apple.com/published/c1b4feb3ba2bd5479aade16f9b5da50e/colors-unified-purple-dark~dark%402x.png) | ![R-176,G-47,B-194](https://docs-assets.developer.apple.com/published/dbd065673a485eeb3312c29c354b4591/colors-unified-accessible-purple-light~dark%402x.png) | ![R-234,G-141,B-255](https://docs-assets.developer.apple.com/published/11b76b54854a9ac5d9d6795f2fcab00f/colors-unified-accessible-purple-dark~dark%402x.png) |
| Pink | [`pink`](https://developer.apple.com/documentation/SwiftUI/Color/pink) | ![R-255,G-45,B-85](https://docs-assets.developer.apple.com/published/6e0dc7bacc17efdc3563a4737198cf54/colors-unified-pink-light~dark%402x.png) | ![R-255,G-55,B-95](https://docs-assets.developer.apple.com/published/1de8e3f5c64309c96dc31a2121b602ad/colors-unified-pink-dark~dark%402x.png) | ![R-231,G-18,B-77](https://docs-assets.developer.apple.com/published/75c97d6808fde0ccb33248928f843baa/colors-unified-accessible-pink-light~dark%402x.png) | ![R-255,G-138,B-196](https://docs-assets.developer.apple.com/published/5a7e04460249ff709a1dd179409167b0/colors-unified-accessible-pink-dark~dark%402x.png) |
| Brown | [`brown`](https://developer.apple.com/documentation/SwiftUI/Color/brown) | ![R-172,G-127,B-94](https://docs-assets.developer.apple.com/published/089f77c7005b1e4753fbdb15c7fbb2ba/colors-unified-brown-light~dark%402x.png) | ![R-183,G-138,B-102](https://docs-assets.developer.apple.com/published/87118d9fb0b8d5fdf2db300fa917946d/colors-unified-brown-dark~dark%402x.png) | ![R-149,G-109,B-81](https://docs-assets.developer.apple.com/published/f97f34fd81b3a8277030d77ffc3a92cd/colors-unified-accessible-brown-light~dark%402x.png) | ![R-219,G-166,B-121](https://docs-assets.developer.apple.com/published/50575ab81511a462d18bc4b9e70a6d4e/colors-unified-accessible-brown-dark~dark%402x.png) |

visionOS system colors use the default dark color values.

### iOS, iPadOS system gray colors

| Name | UIKit API | Default (light) | Default (dark) | Increased contrast (light) | Increased contrast (dark) |
| --- | --- | --- | --- | --- | --- |
| Gray | [`systemGray`](https://developer.apple.com/documentation/UIKit/UIColor/systemGray) | ![R-142,G-142,B-147](https://docs-assets.developer.apple.com/published/fc7844da63dca3eb793031b3fcad009c/ios-default-systemgray~dark%402x.png) | ![R-142,G-142,B-147](https://docs-assets.developer.apple.com/published/fc7844da63dca3eb793031b3fcad009c/ios-default-systemgraydark~dark%402x.png) | ![R-108,G-108,B-112](https://docs-assets.developer.apple.com/published/e625223100131f5dee931632de898184/ios-accessible-systemgray~dark%402x.png) | ![R-174,G-174,B-178](https://docs-assets.developer.apple.com/published/58db62a1037f1c6b1fa2b0bd93a6c8c8/ios-accessible-systemgraydark~dark%402x.png) |
| Gray (2) | [`systemGray2`](https://developer.apple.com/documentation/UIKit/UIColor/systemGray2) | ![R-174,G-174,B-178](https://docs-assets.developer.apple.com/published/58db62a1037f1c6b1fa2b0bd93a6c8c8/ios-default-systemgray2~dark%402x.png) | ![R-99,G-99,B-102](https://docs-assets.developer.apple.com/published/3ec071e8436fcb86681d7d5c8ea70828/ios-default-systemgray2dark~dark%402x.png) | ![R-142,G-142,B-147](https://docs-assets.developer.apple.com/published/fc7844da63dca3eb793031b3fcad009c/ios-accessible-systemgray2~dark%402x.png) | ![R-124,G-124,B-128](https://docs-assets.developer.apple.com/published/a09607f8382407bbfa160033b10133ba/ios-accessible-systemgray2dark~dark%402x.png) |
| Gray (3) | [`systemGray3`](https://developer.apple.com/documentation/UIKit/UIColor/systemGray3) | ![R-199,G-199,B-204](https://docs-assets.developer.apple.com/published/73ae5824564aef7887735b9ca4dd7ff4/ios-default-systemgray3~dark%402x.png) | ![R-72,G-72,B-74](https://docs-assets.developer.apple.com/published/0311ff0cb2b3fd13297ba44f8322e16e/ios-default-systemgray3dark~dark%402x.png) | ![R-174,G-174,B-178](https://docs-assets.developer.apple.com/published/58db62a1037f1c6b1fa2b0bd93a6c8c8/ios-accessible-systemgray3~dark%402x.png) | ![R-84,G-84,B-86](https://docs-assets.developer.apple.com/published/3396810a24c448d953260f9ca4350a31/ios-accessible-systemgray3dark~dark%402x.png) |
| Gray (4) | [`systemGray4`](https://developer.apple.com/documentation/UIKit/UIColor/systemGray4) | ![R-209,G-209,B-214](https://docs-assets.developer.apple.com/published/578fb5c8fe0ce897d2284cecf48c44f1/ios-default-systemgray4~dark%402x.png) | ![R-58,G-58,B-60](https://docs-assets.developer.apple.com/published/7005ec8bc69614738d9e3049492345ae/ios-default-systemgray4dark~dark%402x.png) | ![R-188,G-188,B-192](https://docs-assets.developer.apple.com/published/4dd6e0fd91458cf508ac840976927f08/ios-accessible-systemgray4~dark%402x.png) | ![R-68,G-68,B-70](https://docs-assets.developer.apple.com/published/4ef8ddfba543d3508a474f75f7b85ee0/ios-accessible-systemgray4dark~dark%402x.png) |
| Gray (5) | [`systemGray5`](https://developer.apple.com/documentation/UIKit/UIColor/systemGray5) | ![R-229,G-229,B-234](https://docs-assets.developer.apple.com/published/b7229e6eceb56a0b58d8c415a2c1b22e/ios-default-systemgray5~dark%402x.png) | ![R-44,G-44,B-46](https://docs-assets.developer.apple.com/published/673d4e275b24a1d655d6f7c653e2038a/ios-default-systemgray5dark~dark%402x.png) | ![R-216,G-216,B-220](https://docs-assets.developer.apple.com/published/244c642510d598463d0c2394ff419c30/ios-accessible-systemgray5~dark%402x.png) | ![R-54,G-54,B-56](https://docs-assets.developer.apple.com/published/e211241a8701e439e6bdc4915789e6b2/ios-accessible-systemgray5dark~dark%402x.png) |
| Gray (6) | [`systemGray6`](https://developer.apple.com/documentation/UIKit/UIColor/systemGray6) | ![R-242,G-242,B-247](https://docs-assets.developer.apple.com/published/d23b10d7843ba47642c1497003d8fbe1/ios-default-systemgray6~dark%402x.png) | ![R-28,G-28,B-30](https://docs-assets.developer.apple.com/published/484fbf15a627fbf729a7400f0d07b7c4/ios-default-systemgray6dark~dark%402x.png) | ![R-235,G-235,B-240](https://docs-assets.developer.apple.com/published/0fad10fc530d0760746e46bf164028c8/ios-accessible-systemgray6~dark%402x.png) | ![R-36,G-36,B-38](https://docs-assets.developer.apple.com/published/abcc9796e953856c4c11b0ff83f470b8/ios-accessible-systemgray6dark~dark%402x.png) |

In SwiftUI, the equivalent of `systemGray` is [`gray`](https://developer.apple.com/documentation/SwiftUI/Color/gray).

## Resources

[Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode)

[Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)

[Materials](https://developer.apple.com/design/human-interface-guidelines/materials)

[Apple Design Resources](https://developer.apple.com/design/resources/)

#### Developer documentation

[`Color`](https://developer.apple.com/documentation/SwiftUI/Color) — SwiftUI

[`UIColor`](https://developer.apple.com/documentation/UIKit/UIColor) — UIKit

[Color](https://developer.apple.com/documentation/AppKit/color) — AppKit

#### Videos

## Change log

| Date | Changes |
| --- | --- |
| June 9, 2025 | Updated system color values, and added guidance for Liquid Glass. |
| February 2, 2024 | Distinguished UIKit and SwiftUI gray colors in iOS and iPadOS, and added guidance for balancing brightness levels in visionOS apps. |
| September 12, 2023 | Enhanced guidance for using background color in watchOS views, and added color swatches for tvOS. |
| June 21, 2023 | Updated to include guidance for visionOS. |
| June 5, 2023 | Updated guidance for using background color in watchOS. |
| December 19, 2022 | Corrected RGB values for system mint color (Dark Mode) in iOS and iPadOS. |

Current page is Color