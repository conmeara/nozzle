---
title: "Spacer"
source: "https://developer.apple.com/documentation/swiftui/spacer"
author:
  - "[[Apple Developer Documentation]]"
published:
created: 2025-08-18
description: "A flexible space that expands along the major axis of its containing stack layout, or on both axes if not contained in a stack."
tags:
  - "clippings"
---
[Skip Navigation](https://developer.apple.com/documentation/swiftui/#app-main)

A flexible space that expands along the major axis of its containing stack layout, or on both axes if not contained in a stack.

```
@frozen
struct Spacer
```

## Mentioned in

[Building layouts with stack views](https://developer.apple.com/documentation/swiftui/building-layouts-with-stack-views)

[Adding a background to your view](https://developer.apple.com/documentation/swiftui/adding-a-background-to-your-view)

[Picking container views for your content](https://developer.apple.com/documentation/swiftui/picking-container-views-for-your-content)

## Overview

A spacer creates an adaptive view with no content that expands as much as it can. For example, when placed within an [`HStack`](https://developer.apple.com/documentation/swiftui/hstack), a spacer expands horizontally as much as the stack allows, moving sibling views out of the way, within the limits of the stack’s size. SwiftUI sizes a stack that doesn’t contain a spacer up to the combined ideal widths of the content of the stack’s child views.

The following example provides a simple checklist row to illustrate how you can use a spacer:

```
struct ChecklistRow: View {

    let name: String

    var body: some View {

        HStack {

            Image(systemName: "checkmark")

            Text(name)

        }

        .border(Color.blue)

    }

}
```

![A figure of a blue rectangular border that marks the boundary of an](https://docs-assets.developer.apple.com/published/40d869e902d8bc234a659dfd05d7ff32/Spacer-1~dark%402x.png)

Adding a spacer before the image creates an adaptive view with no content that expands to push the image and text to the right side of the stack. The stack also now expands to take as much space as the parent view allows, shown by the blue border that indicates the boundary of the stack:

```
struct ChecklistRow: View {

    let name: String

    var body: some View {

        HStack {

            Spacer()

            Image(systemName: "checkmark")

            Text(name)

        }

        .border(Color.blue)

    }

}
```

![A figure of a blue rectangular border that marks the boundary of an](https://docs-assets.developer.apple.com/published/ef8abe6c5040cec6797eff2d801eeb20/Spacer-2~dark%402x.png)

Moving the spacer between the image and the name pushes those elements to the left and right sides of the [`HStack`](https://developer.apple.com/documentation/swiftui/hstack), respectively. Because the stack contains the spacer, it expands to take as much horizontal space as the parent view allows; the blue border indicates its size:

```
struct ChecklistRow: View {

    let name: String

    var body: some View {

        HStack {

            Image(systemName: "checkmark")

            Spacer()

            Text(name)

        }

        .border(Color.blue)

    }

}
```

![A figure of a blue rectangular border that marks the boundary of an](https://docs-assets.developer.apple.com/published/5269b7a7cdbf3391878c3df7ec18f7f3/Spacer-3~dark%402x.png)

Adding two spacer views on the outside of the stack leaves the image and text together, while the stack expands to take as much horizontal space as the parent view allows:

```
struct ChecklistRow: View {

    let name: String

    var body: some View {

        HStack {

            Spacer()

            Image(systemName: "checkmark")

            Text(name)

            Spacer()

        }

        .border(Color.blue)

    }

}
```

![A figure of a blue rectangular border marks the boundary of an HStack,](https://docs-assets.developer.apple.com/published/84e1f1d1e23fb20f251379a608a529b2/Spacer-4~dark%402x.png)

## Topics

### Creating a spacer

[`init(minLength: CGFloat?)`](https://developer.apple.com/documentation/swiftui/spacer/init\(minlength:\))

[`varminLength: CGFloat?`](https://developer.apple.com/documentation/swiftui/spacer/minlength)

The minimum length this spacer can be shrunk to, along the axis or axes of expansion.

## Relationships

### Conforms To

- [`BitwiseCopyable`](https://developer.apple.com/documentation/Swift/BitwiseCopyable)
- [`Copyable`](https://developer.apple.com/documentation/Swift/Copyable)
- [`Sendable`](https://developer.apple.com/documentation/Swift/Sendable)
- [`SendableMetatype`](https://developer.apple.com/documentation/Swift/SendableMetatype)
- [`View`](https://developer.apple.com/documentation/swiftui/view)

## See Also

### Separators

[`structDivider`](https://developer.apple.com/documentation/swiftui/divider)

A visual element that can be used to separate other content.

Current page is Spacer