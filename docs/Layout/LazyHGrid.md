---
title: "LazyHGrid"
source: "https://developer.apple.com/documentation/swiftui/lazyhgrid"
author:
  - "[[Apple Developer Documentation]]"
published:
created: 2025-08-18
description: "A container view that arranges its child views in a grid that grows horizontally, creating items only as needed."
tags:
  - "clippings"
---
[Skip Navigation](https://developer.apple.com/documentation/swiftui/#app-main)

A container view that arranges its child views in a grid that grows horizontally, creating items only as needed.

```
struct LazyHGrid<Content> where Content : View
```

## Mentioned in

[Picking container views for your content](https://developer.apple.com/documentation/swiftui/picking-container-views-for-your-content)

## Overview

Use a lazy horizontal grid when you want to display a large, horizontally scrollable collection of views arranged in a two dimensional layout. The first view that you provide to the grid’s `content` closure appears in the top row of the column that’s on the grid’s leading edge. Additional views occupy successive cells in the grid, filling the first column from top to bottom, then the second column, and so on. The number of columns can grow unbounded, but you specify the number of rows by providing a corresponding number of [`GridItem`](https://developer.apple.com/documentation/swiftui/griditem) instances to the grid’s initializer.

The grid in the following example defines two rows and uses a [`ForEach`](https://developer.apple.com/documentation/swiftui/foreach) structure to repeatedly generate a pair of [`Text`](https://developer.apple.com/documentation/swiftui/text) views for the rows in each column:

```
struct HorizontalSmileys: View {

    let rows = [GridItem(.fixed(30)), GridItem(.fixed(30))]

    var body: some View {

        ScrollView(.horizontal) {

            LazyHGrid(rows: rows) {

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

For each column in the grid, the top row shows a Unicode code point from the “Smileys” group, and the bottom shows its corresponding emoji:

![A screenshot of a row of hexadecimal numbers above a row of emoji,](https://docs-assets.developer.apple.com/published/63fa599de99e4c1ed1373d24b1e640d3/LazyHGrid-1-iOS~dark%402x.png)

You can achieve a similar layout using a [`Grid`](https://developer.apple.com/documentation/swiftui/grid) container. Unlike a lazy grid, which creates child views only when SwiftUI needs to display them, a regular grid creates all of its child views right away. This enables the grid to provide better support for cell spacing and alignment. Only use a lazy grid if profiling your app shows that a [`Grid`](https://developer.apple.com/documentation/swiftui/grid) view performs poorly because it tries to load too many views at once.

## Topics

### Creating a horizontal grid

[`init(rows: [GridItem], alignment: VerticalAlignment, spacing: CGFloat?, pinnedViews: PinnedScrollableViews, content: () -> Content)`](https://developer.apple.com/documentation/swiftui/lazyhgrid/init\(rows:alignment:spacing:pinnedviews:content:\))

Creates a grid that grows horizontally.

## Relationships

### Conforms To

- [`View`](https://developer.apple.com/documentation/swiftui/view)

## See Also

### Dynamically arranging views in two dimensions

[`structLazyVGrid`](https://developer.apple.com/documentation/swiftui/lazyvgrid)

A container view that arranges its child views in a grid that grows vertically, creating items only as needed.

[`structGridItem`](https://developer.apple.com/documentation/swiftui/griditem)

A description of a row or a column in a lazy grid.

Current page is LazyHGrid