---
title: "ZStack"
source: "https://developer.apple.com/documentation/swiftui/zstack"
author:
  - "[[Apple Developer Documentation]]"
published:
created: 2025-08-18
description: "A view that overlays its subviews, aligning them in both axes."
tags:
  - "clippings"
---
[Skip Navigation](https://developer.apple.com/documentation/swiftui/#app-main)

A view that overlays its subviews, aligning them in both axes.

```
@frozen
struct ZStack<Content> where Content : View
```

## Mentioned in

[Building layouts with stack views](https://developer.apple.com/documentation/swiftui/building-layouts-with-stack-views)

[Laying out a simple view](https://developer.apple.com/documentation/swiftui/laying-out-a-simple-view)

[Adding a background to your view](https://developer.apple.com/documentation/swiftui/adding-a-background-to-your-view)

[Making fine adjustments to a view’s position](https://developer.apple.com/documentation/swiftui/making-fine-adjustments-to-a-view-s-position)

[Aligning views within a stack](https://developer.apple.com/documentation/swiftui/aligning-views-within-a-stack)

## Overview

The `ZStack` assigns each successive subview a higher z-axis value than the one before it, meaning later subviews appear “on top” of earlier ones.

The following example creates a `ZStack` of 100 x 100 point [`Rectangle`](https://developer.apple.com/documentation/swiftui/rectangle) views filled with one of six colors, offsetting each successive subview by 10 points so they don’t completely overlap:

```
let colors: [Color] =

    [.red, .orange, .yellow, .green, .blue, .purple]

var body: some View {

    ZStack {

        ForEach(0..<colors.count) {

            Rectangle()

                .fill(colors[$0])

                .frame(width: 100, height: 100)

                .offset(x: CGFloat($0) * 10.0,

                        y: CGFloat($0) * 10.0)

        }

    }

}
```

![Six squares of different colors, stacked atop each other, with a 10-point](https://docs-assets.developer.apple.com/published/a01f19de9badebe45a5e43e5b54a5518/SwiftUI-ZStack-offset-rectangles~dark%402x.png)

The `ZStack` uses an [`Alignment`](https://developer.apple.com/documentation/swiftui/alignment) to set the x- and y-axis coordinates of each subview, defaulting to a [`center`](https://developer.apple.com/documentation/swiftui/alignment/center) alignment. In the following example, the `ZStack` uses a [`bottomLeading`](https://developer.apple.com/documentation/swiftui/alignment/bottomleading) alignment to lay out two subviews, a red 100 x 50 point rectangle below, and a blue 50 x 100 point rectangle on top. Because of the alignment value, both rectangles share a bottom-left corner with the `ZStack` (in locales where left is the leading side).

```
var body: some View {

    ZStack(alignment: .bottomLeading) {

        Rectangle()

            .fill(Color.red)

            .frame(width: 100, height: 50)

        Rectangle()

            .fill(Color.blue)

            .frame(width:50, height: 100)

    }

    .border(Color.green, width: 1)

}
```

![A green 100 by 100 square containing two overlapping rectangles: on the](https://docs-assets.developer.apple.com/published/45b7459d4d4f6d23249dd18d23e50f3f/SwiftUI-ZStack-alignment~dark%402x.png)

## Topics

### Creating a stack

[`init(alignment: Alignment, content: () -> Content)`](https://developer.apple.com/documentation/swiftui/zstack/init\(alignment:content:\))

Creates an instance with the given alignment.

### Supporting symbols

[`structZStackContent3D`](https://developer.apple.com/documentation/swiftui/zstackcontent3d)

A type that adds spacing to a [`ZStack`](https://developer.apple.com/documentation/swiftui/zstack).

### Initializers

[`init<V>(alignment: Alignment, spacing: CGFloat?, content: () -> V)`](https://developer.apple.com/documentation/swiftui/zstack/init\(alignment:spacing:content:\))

Creates an instance with the given spacing and alignment.

## Relationships

### Conforms To

- [`View`](https://developer.apple.com/documentation/swiftui/view)

## See Also

### Layering views

[Adding a background to your view](https://developer.apple.com/documentation/swiftui/adding-a-background-to-your-view)

Compose a background behind your view and extend it beyond the safe area insets.

[`funczIndex(Double) -> someView`](https://developer.apple.com/documentation/swiftui/view/zindex\(_:\))

Controls the display order of overlapping views.

[`funcbackground<V>(alignment: Alignment, content: () -> V) -> someView`](https://developer.apple.com/documentation/swiftui/view/background\(alignment:content:\))

Layers the views that you specify behind this view.

[`funcbackground<S>(S, ignoresSafeAreaEdges: Edge.Set) -> someView`](https://developer.apple.com/documentation/swiftui/view/background\(_:ignoressafeareaedges:\))

Sets the view’s background to a style.

[`funcbackground(ignoresSafeAreaEdges: Edge.Set) -> someView`](https://developer.apple.com/documentation/swiftui/view/background\(ignoressafeareaedges:\))

Sets the view’s background to the default background style.

[`funcbackground(_:in:fillStyle:)`](https://developer.apple.com/documentation/swiftui/view/background\(_:in:fillstyle:\))

Sets the view’s background to an insettable shape filled with a style.

[`funcbackground(in:fillStyle:)`](https://developer.apple.com/documentation/swiftui/view/background\(in:fillstyle:\))

Sets the view’s background to an insettable shape filled with the default background style.

[`funcoverlay<V>(alignment: Alignment, content: () -> V) -> someView`](https://developer.apple.com/documentation/swiftui/view/overlay\(alignment:content:\))

Layers the views that you specify in front of this view.

[`funcoverlay<S>(S, ignoresSafeAreaEdges: Edge.Set) -> someView`](https://developer.apple.com/documentation/swiftui/view/overlay\(_:ignoressafeareaedges:\))

Layers the specified style in front of this view.

[`funcoverlay<S, T>(S, in: T, fillStyle: FillStyle) -> someView`](https://developer.apple.com/documentation/swiftui/view/overlay\(_:in:fillstyle:\))

Layers a shape that you specify in front of this view.

[`varbackgroundMaterial: Material?`](https://developer.apple.com/documentation/swiftui/environmentvalues/backgroundmaterial)

The material underneath the current view.

[`funccontainerBackground<S>(S, for: ContainerBackgroundPlacement) -> someView`](https://developer.apple.com/documentation/swiftui/view/containerbackground\(_:for:\))

Sets the container background of the enclosing container using a view.

[`funccontainerBackground<V>(for: ContainerBackgroundPlacement, alignment: Alignment, content: () -> V) -> someView`](https://developer.apple.com/documentation/swiftui/view/containerbackground\(for:alignment:content:\))

Sets the container background of the enclosing container using a view.

[`structContainerBackgroundPlacement`](https://developer.apple.com/documentation/swiftui/containerbackgroundplacement)

The placement of a container background.

Current page is ZStack