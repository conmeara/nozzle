---
title: "Picking container views for your content"
source: "https://developer.apple.com/documentation/swiftui/picking-container-views-for-your-content"
author:
  - "[[Apple Developer Documentation]]"
published:
created: 2025-08-18
description: "Build flexible user interfaces by using stacks, grids, lists, and forms."
tags:
  - "clippings"
---
[Skip Navigation](https://developer.apple.com/documentation/swiftui/#app-main)

Build flexible user interfaces by using stacks, grids, lists, and forms.

## Overview

SwiftUI provides a range of container views that group and repeat views. Use some containers purely for structure and layout, like stack views, lazy stack views, and grid views. Use others, like lists and forms, to also adopt system-standard visuals and interactivity.

Choosing the most appropriate container views for each part of your app’s user interface is an important skill to learn; it helps you with everything from positioning two views next to each other, to creating complex layouts with hundreds of elements.

Stack views are the most primitive layout container available in SwiftUI. Use stacks to group collections of views into horizontal or vertical lines, or to stack them on top of one another.

Use [`HStack`](https://developer.apple.com/documentation/swiftui/hstack) to lay out views in a horizontal line, [`VStack`](https://developer.apple.com/documentation/swiftui/vstack) to position views in a vertical line, and [`ZStack`](https://developer.apple.com/documentation/swiftui/zstack) to layer views on top of one another. Then, combine stack views to compose more complex layouts. These three kinds of stacks, along with their alignment and spacing properties, view modifiers, and [`Spacer`](https://developer.apple.com/documentation/swiftui/spacer) views combine to allow extensive layout flexibility.

![A diagram showing how a generic user profile layout might utilize stack views. The diagram shows the rendered layout next to an exploded, 3D illustration of the view hierarchy showing four layers of views stacked on top of each other. The lowest level of the hierarchy is a ZStack; above that is an Image view, then an HStack, and finally a VStack and Spacer view at the highest level.](https://docs-assets.developer.apple.com/published/b05428e50843dc066ba1295550c2ba49/Picking-Container-Views-for-Your-Content-1~dark%402x.png)

You often use stack views as building blocks inside other container views. For example, a [`List`](https://developer.apple.com/documentation/swiftui/list) typically contains stack views, with which you lay out views inside each row.

For more information on using stack views to lay out views, see [Building layouts with stack views](https://developer.apple.com/documentation/swiftui/building-layouts-with-stack-views).

### Repeat views or groups of views

You can also use [`HStack`](https://developer.apple.com/documentation/swiftui/hstack), [`VStack`](https://developer.apple.com/documentation/swiftui/vstack), [`LazyHStack`](https://developer.apple.com/documentation/swiftui/lazyhstack), and [`LazyVStack`](https://developer.apple.com/documentation/swiftui/lazyvstack) to repeat views or groups of views. Place a stack view inside a [`ScrollView`](https://developer.apple.com/documentation/swiftui/scrollview) so your content can expand beyond the bounds of its container. Users can simultaneously scroll horizontally, vertically, or in both directions.

Stack views and lazy stacks have similar functionality, and they may feel interchangeable, but they each have strengths in different situations. Stack views load their child views all at once, making layout fast and reliable, because the system knows the size and shape of every subview as it loads them. Lazy stacks trade some degree of layout correctness for performance, because the system only calculates the geometry for subviews as they become visible.

![A diagram showing how the system loads views on demand in a lazy stack view container.](https://docs-assets.developer.apple.com/published/96696c972b52f80e3f99d4d8a8d29399/Picking-Container-Views-for-Your-Content-2~dark%402x.png)

When choosing the type of stack view to use, always start with a standard stack view and only switch to a lazy stack if profiling your code shows a worthwhile performance improvement. For more information on lazy stack views and how to measure your app’s view loading performance, see [Creating performant scrollable stacks](https://developer.apple.com/documentation/swiftui/creating-performant-scrollable-stacks).

### Position views in a two-dimensional layout

To lay out views horizontally and vertically at the same time, use a [`LazyVGrid`](https://developer.apple.com/documentation/swiftui/lazyvgrid) or [`LazyHGrid`](https://developer.apple.com/documentation/swiftui/lazyhgrid). Grids are a good container choice to lay out content that naturally displays in square containers, like an image gallery. Grids are also a good choice to scale user interface layouts up for display on larger devices. For example, a directory of contact information might suit a list or vertical stack on an iPhone, but might fit more naturally in a grid layout when scaled up to a larger device like the iPad or Mac.

![A diagram showing how a user interface might scale up from a device with a smaller screen, such as an iPhone onto a device with a larger screen, like a Mac.](https://docs-assets.developer.apple.com/published/9e0528f0c35e969583b8c7265e63830b/Picking-Container-Views-for-Your-Content-3~dark%402x.png)

Like stack views, SwiftUI grid views don’t inherently include a scrolling viewport; place them inside a [`ScrollView`](https://developer.apple.com/documentation/swiftui/scrollview) if the content might be larger than the available space.

[`List`](https://developer.apple.com/documentation/swiftui/list) views in SwiftUI are conceptually similar to the combination of a [`LazyVStack`](https://developer.apple.com/documentation/swiftui/lazyvstack) and [`ScrollView`](https://developer.apple.com/documentation/swiftui/scrollview), but by default will include platform-appropriate visual styling around and between their contained items. For example, when running on iOS, the default configuration of a [`List`](https://developer.apple.com/documentation/swiftui/list) adds separator lines between rows, and draws disclosure indicators for items which have navigation, and where the list is contained in a [`NavigationView`](https://developer.apple.com/documentation/swiftui/navigationview).

[`List`](https://developer.apple.com/documentation/swiftui/list) views also support platform-appropriate interactivity for common tasks such as inserting, reordering, and removing items. For example, adding the [`onDelete(perform:)`](https://developer.apple.com/documentation/swiftui/dynamicviewcontent/ondelete\(perform:\)) modifier to a [`ForEach`](https://developer.apple.com/documentation/swiftui/foreach) inside a [`List`](https://developer.apple.com/documentation/swiftui/list) will enable system-standard swipe-to-delete interactivity.

Like [`LazyHStack`](https://developer.apple.com/documentation/swiftui/lazyhstack) and [`LazyVStack`](https://developer.apple.com/documentation/swiftui/lazyvstack), rows inside a SwiftUI [`List`](https://developer.apple.com/documentation/swiftui/list) also load lazily, and there is no non-lazy equivalent. Lists inherently scroll when necessary, and you don’t need to wrap them in a [`ScrollView`](https://developer.apple.com/documentation/swiftui/scrollview).

### Group views and controls for data entry

Use [`Form`](https://developer.apple.com/documentation/swiftui/form) to build data-entry interfaces, settings, or preference screens that use system-standard controls.

![A diagram showing a macOS preferences window, and an iOS settings screen next to each other. The screens both contain the same settings, but they use different, platform-appropriate controls.](https://docs-assets.developer.apple.com/published/48b3e06ca2e6db2812a885e4a32b1240/Picking-Container-Views-for-Your-Content-4~dark%402x.png)

Like all SwiftUI views, forms display their content in a platform-appropriate way. Be aware that the layout of controls inside a [`Form`](https://developer.apple.com/documentation/swiftui/form) may differ significantly based on the platform. For example, a [`Picker`](https://developer.apple.com/documentation/swiftui/picker) control in a [`Form`](https://developer.apple.com/documentation/swiftui/form) on iOS adds navigation, showing the picker’s choices on a separate screen, while the same [`Picker`](https://developer.apple.com/documentation/swiftui/picker) on macOS displays a pop-up button or set of radio buttons.

Current page is Picking container views for your content