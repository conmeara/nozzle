---
title: "LazyVGrid"
source: "https://developer.apple.com/documentation/swiftui/lazyvgrid"
author:
  - "[[Apple Developer Documentation]]"
published:
created: 2025-08-18
description: "A container view that arranges its child views in a grid that grows vertically, creating items only as needed."
tags:
  - "clippings"
---
[Skip Navigation](https://developer.apple.com/documentation/swiftui/#app-main)

A container view that arranges its child views in a grid that grows vertically, creating items only as needed.

```
struct LazyVGrid<Content> where Content : View
```

## Mentioned in

[Picking container views for your content](https://developer.apple.com/documentation/swiftui/picking-container-views-for-your-content)

## Overview

Use a lazy vertical grid when you want to display a large, vertically scrollable collection of views arranged in a two dimensional layout. The first view that you provide to the grid’s `content` closure appears in the top row of the column that’s on the grid’s leading edge. Additional views occupy successive cells in the grid, filling the first row from leading to trailing edges, then the second row, and so on. The number of rows can grow unbounded, but you specify the number of columns by providing a corresponding number of [`GridItem`](https://developer.apple.com/documentation/swiftui/griditem) instances to the grid’s initializer.

The grid in the following example defines two columns and uses a [`ForEach`](https://developer.apple.com/documentation/swiftui/foreach) structure to repeatedly generate a pair of [`Text`](https://developer.apple.com/documentation/swiftui/text) views for the columns in each row:

```
struct VerticalSmileys: View {

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {

         ScrollView {

             LazyVGrid(columns: columns) {

                 ForEach(0x1f600...0x1f679, id: \.self) { value in

                     Text(String(format: "%x", value))

                     Text(emoji(value))

                         .font(.largeTitle)

                 }

             }

         }

    }

    private func emoji(_ value: Int) -> String {

        guard let scalar = UnicodeScalar(value) else { return "?" }

        return String(Character(scalar))

    }

}
```

For each row in the grid, the first column shows a Unicode code point from the “Smileys” group, and the second shows its corresponding emoji:

![A screenshot of a colunb of hexadecimal numbers to the left of a column](https://docs-assets.developer.apple.com/published/639b1fc5d2283f9eafed17d9109ca47d/LazyVGrid-1-iOS~dark%402x.png)

You can achieve a similar layout using a [`Grid`](https://developer.apple.com/documentation/swiftui/grid) container. Unlike a lazy grid, which creates child views only when SwiftUI needs to display them, a regular grid creates all of its child views right away. This enables the grid to provide better support for cell spacing and alignment. Only use a lazy grid if profiling your app shows that a [`Grid`](https://developer.apple.com/documentation/swiftui/grid) view performs poorly because it tries to load too many views at once.

## Topics

### Creating a vertical grid

[`init(columns: [GridItem], alignment: HorizontalAlignment, spacing: CGFloat?, pinnedViews: PinnedScrollableViews, content: () -> Content)`](https://developer.apple.com/documentation/swiftui/lazyvgrid/init\(columns:alignment:spacing:pinnedviews:content:\))

Creates a grid that grows vertically.

## Relationships

### Conforms To

- [`View`](https://developer.apple.com/documentation/swiftui/view)

## See Also

### Dynamically arranging views in two dimensions

[`structLazyHGrid`](https://developer.apple.com/documentation/swiftui/lazyhgrid)

A container view that arranges its child views in a grid that grows horizontally, creating items only as needed.

[`structGridItem`](https://developer.apple.com/documentation/swiftui/griditem)

A description of a row or a column in a lazy grid.

Current page is LazyVGrid