---
title: "Building layouts with stack views"
source: "https://developer.apple.com/documentation/swiftui/building-layouts-with-stack-views"
author:
  - "[[Apple Developer Documentation]]"
published:
created: 2025-08-18
description: "Compose complex layouts from primitive container views."
tags:
  - "clippings"
---
[Skip Navigation](https://developer.apple.com/documentation/swiftui/#app-main)

Compose complex layouts from primitive container views.

## Overview

Individually, [`HStack`](https://developer.apple.com/documentation/swiftui/hstack), [`VStack`](https://developer.apple.com/documentation/swiftui/vstack), and [`ZStack`](https://developer.apple.com/documentation/swiftui/zstack) are simple views. [`HStack`](https://developer.apple.com/documentation/swiftui/hstack) positions views in a horizontal line, [`VStack`](https://developer.apple.com/documentation/swiftui/vstack) positions them in a vertical line, and [`ZStack`](https://developer.apple.com/documentation/swiftui/zstack) overlays views on top of one another.

![A diagram showing the three different stack views; Horizontal, vertical, and depth. Each stack contains a square and a circle shape stacked together either side-by-side horizontally or vertically, or layered one on top of the other.](https://docs-assets.developer.apple.com/published/2f4d6bcff68597d513bff05a40b3ae41/Building-Layouts-with-Stack-Views-1~dark%402x.png)

When you initialize them with default parameters, stack views center align their content and insert a small amount of spacing between each contained view. But, when you combine and customize stacks with view modifiers, [`Spacer`](https://developer.apple.com/documentation/swiftui/spacer), and [`Divider`](https://developer.apple.com/documentation/swiftui/divider) views, you can create highly flexible and complex layouts.

### Plan your layout hierarchy

Think about a layout in terms of how you might create it using the various types of stack views as you start to translate your design into code. Break down complex designs into smaller, simpler pieces you can build with stack views.

For example, you might build this profile view using three stack views:

![A diagram showing how a generic user profile layout might utilize stack views. The diagram shows the rendered layout next to an exploded, 3D illustration of the view hierarchy showing four layers of views stacked on top of each other. The lowest level of the hierarchy is a ZStack; above that is an Image view, then an HStack, and finally a VStack and Spacer view at the highest level.](https://docs-assets.developer.apple.com/published/5cda30e96043531837daece8016db51b/Building-Layouts-with-Stack-Views-2~dark%402x.png)

A [`ZStack`](https://developer.apple.com/documentation/swiftui/zstack) contains an [`Image`](https://developer.apple.com/documentation/swiftui/image) view that displays a profile picture with a semi-transparent [`HStack`](https://developer.apple.com/documentation/swiftui/hstack) overlaid on top. The [`HStack`](https://developer.apple.com/documentation/swiftui/hstack) contains a [`VStack`](https://developer.apple.com/documentation/swiftui/vstack) with a pair of [`Text`](https://developer.apple.com/documentation/swiftui/text) views inside it, and a [`Spacer`](https://developer.apple.com/documentation/swiftui/spacer) view pushes the [`VStack`](https://developer.apple.com/documentation/swiftui/vstack) to the leading side.

To create this stack view:

```
struct ProfileView: View {

    var body: some View {

        ZStack(alignment: .bottom) {

            Image("ProfilePicture")

                .resizable()

                .aspectRatio(contentMode: .fit)

            HStack {

                VStack(alignment: .leading) {

                    Text("Rachael Chiseck")

                        .font(.headline)

                    Text("Chief Executive Officer")

                        .font(.subheadline)

                }

                Spacer()

            }

            .padding()

            .foregroundColor(.primary)

            .background(Color.primary

                            .colorInvert()

                            .opacity(0.75))

        }

    }

}
```

### Position views with alignment and spacer views

Align any contained views inside a stack view by using a combination of the `alignment` property, [`Spacer`](https://developer.apple.com/documentation/swiftui/spacer), and [`Divider`](https://developer.apple.com/documentation/swiftui/divider) views.

In the previous example layout, the [`VStack`](https://developer.apple.com/documentation/swiftui/vstack) that contains the two [`Text`](https://developer.apple.com/documentation/swiftui/text) views uses the [`leading`](https://developer.apple.com/documentation/swiftui/horizontalalignment/leading) alignment:

![A diagram showing two views being aligned in three different ways in a vertical stack view. Leading, where both views are aligned to the leading edge of the stack. Centered, where both views are centered in the stack. Finally trailing, where both views are aligned with the trailing edge](https://docs-assets.developer.apple.com/published/780048bcf471fb005b1f820f2d449b7d/Building-Layouts-with-Stack-Views-3~dark%402x.png)

The `alignment` property doesn’t position the [`VStack`](https://developer.apple.com/documentation/swiftui/vstack) inside its container; instead, it positions the views inside the [`VStack`](https://developer.apple.com/documentation/swiftui/vstack).

The `alignment` property of a [`VStack`](https://developer.apple.com/documentation/swiftui/vstack) only applies to the horizontal alignment of the contained controls using [`HorizontalAlignment`](https://developer.apple.com/documentation/swiftui/horizontalalignment). Similarly, the `alignment` property for an [`HStack`](https://developer.apple.com/documentation/swiftui/hstack) only controls the vertical alignment using [`VerticalAlignment`](https://developer.apple.com/documentation/swiftui/verticalalignment). Finally, you can align views inside a [`ZStack`](https://developer.apple.com/documentation/swiftui/zstack) along both axes with [`Alignment`](https://developer.apple.com/documentation/swiftui/alignment).

Use [`Spacer`](https://developer.apple.com/documentation/swiftui/spacer) views to align views along the primary axis of an [`HStack`](https://developer.apple.com/documentation/swiftui/hstack) or [`VStack`](https://developer.apple.com/documentation/swiftui/vstack). Spacers expand to fill any available space and push content apart from other views or the edges of the stack.

![A diagram showing the use of spacer views in three vertical stack views. The first stack shows a spacer view pushing another view to the top of its container. The second stack shows a spacer view pushing two views apart, ending with the views aligned to the top and bottom of their container. a spacer view pushing another view to the bottom of its container.](https://docs-assets.developer.apple.com/published/f514414d01e78a4263b32fbc7d063e16/Building-Layouts-with-Stack-Views-4~dark%402x.png)

[`Divider`](https://developer.apple.com/documentation/swiftui/divider) views also add space in between a stack’s subviews, but only insert enough space to draw a line across the stack’s minor axis. They don’t expand to fill available space.

### Create adaptive layouts instead of explicit layouts

Wherever possible, define structure and hierarchy rather than explicitly positioning view frames. Instead of using explicit heights and widths for views, let them expand to fill available space. Adaptive layouts that you build adapt more easily to different device sizes and platforms.

It is possible to create this article’s example layout with two stack views rather than three, by manipulating the [`Text`](https://developer.apple.com/documentation/swiftui/text) view frames explicitly. While the output might look the same, the code to implement it is more brittle, and might not scale as well across devices of different size classes.

You may need to make adjustments to a layout that uses explicit adjustments by using view modifiers such as [`frame(width:height:alignment:)`](https://developer.apple.com/documentation/swiftui/view/frame\(width:height:alignment:\)) or [`position(x:y:)`](https://developer.apple.com/documentation/swiftui/view/position\(x:y:\)), but only consider this when you can’t achieve your desired layout in an adaptive, flexible way. For more information on making fine adjustments to view layout, see [Making fine adjustments to a view’s position](https://developer.apple.com/documentation/swiftui/making-fine-adjustments-to-a-view-s-position).

### Add depth in alternative ways

In some situations it may make sense to add depth to your layout by using the [`overlay(_:alignment:)`](https://developer.apple.com/documentation/swiftui/view/overlay\(_:alignment:\)) and [`background(_:alignment:)`](https://developer.apple.com/documentation/swiftui/view/background\(_:alignment:\)) view modifiers instead of a [`ZStack`](https://developer.apple.com/documentation/swiftui/zstack). The background view modifier places another view behind the view you’re modifying, and overlay places a view on top of it.

Choose between a stack-based approach and the view modifier approach based on how you want to determine the size of the final layout. If your layout has one dominant view that defines the size of the layout, use the [`overlay(_:alignment:)`](https://developer.apple.com/documentation/swiftui/view/overlay\(_:alignment:\)) or [`background(_:alignment:)`](https://developer.apple.com/documentation/swiftui/view/background\(_:alignment:\)) view modifier on that view. If you want the final view size to come from an aggregation of all the contained views, use a [`ZStack`](https://developer.apple.com/documentation/swiftui/zstack).

For example, this code overlays a `ProfileDetail` view on top of the [`Image`](https://developer.apple.com/documentation/swiftui/image) view:

```
struct ProfileViewWithOverlay: View {

    var body: some View {

        VStack {

            Image("ProfilePicture")

                .resizable()

                .aspectRatio(contentMode: .fit)

                .overlay(ProfileDetail(), alignment: .bottom)

        }

    }

}

struct ProfileDetail: View {

    var body: some View {

        HStack {

            VStack(alignment: .leading) {

                Text("Rachael Chiseck")

                    .font(.headline)

                Text("Chief Executive Officer")

                    .font(.subheadline)

            }

            Spacer()

        }

        .padding()

        .foregroundColor(.primary)

        .background(Color.primary

                        .colorInvert()

                        .opacity(0.75))

    }

}
```

## See Also

### Statically arranging views in one dimension

[`structHStack`](https://developer.apple.com/documentation/swiftui/hstack)

A view that arranges its subviews in a horizontal line.

[`structVStack`](https://developer.apple.com/documentation/swiftui/vstack)

A view that arranges its subviews in a vertical line.

Current page is Building layouts with stack views