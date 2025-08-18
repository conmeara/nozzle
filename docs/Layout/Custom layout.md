---
title: "Custom layout"
source: "https://developer.apple.com/documentation/swiftui/custom-layout"
author:
  - "[[Apple Developer Documentation]]"
published:
created: 2025-08-18
description: "Place views in custom arrangements and create animated transitions between layout types."
tags:
  - "clippings"
---
[Skip Navigation](https://developer.apple.com/documentation/swiftui/#app-main)

Place views in custom arrangements and create animated transitions between layout types.

## Overview

You can create complex view layouts using the built-in layout containers and layout view modifiers that SwiftUI provides. However, if you need behavior that you can’t achieve with the built-in layout tools, create a custom layout container type using the [`Layout`](https://developer.apple.com/documentation/swiftui/layout) protocol. A container that you define asks for the sizes of all its subviews, and then indicates where to place the subviews within its own bounds.

![](https://docs-assets.developer.apple.com/published/098af88e7ef1601f537924b942ecfb67/custom-layout-hero%402x.png)

You can also create animated transitions among layout types that conform to the [`Layout`](https://developer.apple.com/documentation/swiftui/layout) procotol, including both built-in and custom layouts.

For design guidance, see [Layout](https://developer.apple.com/design/Human-Interface-Guidelines/layout) in the Human Interface Guidelines.

## Topics

### Creating a custom layout container

[Composing custom layouts with Swift  UI](https://developer.apple.com/documentation/swiftui/composing_custom_layouts_with_swiftui)

Arrange views in your app’s interface using layout tools that SwiftUI provides.

[`protocolLayout`](https://developer.apple.com/documentation/swiftui/layout)

A type that defines the geometry of a collection of views.

[`structLayoutSubview`](https://developer.apple.com/documentation/swiftui/layoutsubview)

A proxy that represents one subview of a layout.

[`structLayoutSubviews`](https://developer.apple.com/documentation/swiftui/layoutsubviews)

A collection of proxy values that represent the subviews of a layout view.

### Configuring a custom layout

[`structLayoutProperties`](https://developer.apple.com/documentation/swiftui/layoutproperties)

Layout-specific properties of a layout container.

[`structProposedViewSize`](https://developer.apple.com/documentation/swiftui/proposedviewsize)

A proposal for the size of a view.

[`structViewSpacing`](https://developer.apple.com/documentation/swiftui/viewspacing)

A collection of the geometric spacing preferences of a view.

### Associating values with views in a custom layout

[`funclayoutValue<K>(key: K.Type, value: K.Value) -> someView`](https://developer.apple.com/documentation/swiftui/view/layoutvalue\(key:value:\))

Associates a value with a custom layout property.

[`protocolLayoutValueKey`](https://developer.apple.com/documentation/swiftui/layoutvaluekey)

A key for accessing a layout value of a layout container’s subviews.

### Transitioning between layout types

[`structAnyLayout`](https://developer.apple.com/documentation/swiftui/anylayout)

A type-erased instance of the layout protocol.

[`structHStackLayout`](https://developer.apple.com/documentation/swiftui/hstacklayout)

A horizontal container that you can use in conditional layouts.

[`structVStackLayout`](https://developer.apple.com/documentation/swiftui/vstacklayout)

A vertical container that you can use in conditional layouts.

[`structZStackLayout`](https://developer.apple.com/documentation/swiftui/zstacklayout)

An overlaying container that you can use in conditional layouts.

[`structGridLayout`](https://developer.apple.com/documentation/swiftui/gridlayout)

A grid that you can use in conditional layouts.

## See Also

### View layout

[Layout fundamentals](https://developer.apple.com/documentation/swiftui/layout-fundamentals)

Arrange views inside built-in layout containers like stacks and grids.

[Layout adjustments](https://developer.apple.com/documentation/swiftui/layout-adjustments)

Make fine adjustments to alignment, spacing, padding, and other layout parameters.

[Lists](https://developer.apple.com/documentation/swiftui/lists)

Display a structured, scrollable column of information.

[Tables](https://developer.apple.com/documentation/swiftui/tables)

Display selectable, sortable data arranged in rows and columns.

[View groupings](https://developer.apple.com/documentation/swiftui/view-groupings)

Present views in different kinds of purpose-driven containers, like forms or control groups.

[Scroll views](https://developer.apple.com/documentation/swiftui/scroll-views)

Enable people to scroll to content that doesn’t fit in the current display.

Current page is Custom layout