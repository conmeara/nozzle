---
title: "init(alignment:content:)"
source: "https://developer.apple.com/documentation/swiftui/gridrow/init(alignment:content:)"
author:
  - "[[Apple Developer Documentation]]"
published:
created: 2025-08-18
description: "Creates a horizontal row of child views in a grid."
tags:
  - "clippings"
---
[Skip Navigation](https://developer.apple.com/documentation/swiftui/gridrow/#app-main)

## Parameters

`alignment`

An optional [`VerticalAlignment`](https://developer.apple.com/documentation/swiftui/verticalalignment) for the row. If you don’t specify a value, the row uses the vertical alignment component of the [`Alignment`](https://developer.apple.com/documentation/swiftui/alignment) parameter that you specify in the grid’s [`init(alignment:horizontalSpacing:verticalSpacing:content:)`](https://developer.apple.com/documentation/swiftui/grid/init\(alignment:horizontalspacing:verticalspacing:content:\)) initializer, which is [`center`](https://developer.apple.com/documentation/swiftui/verticalalignment/center) by default.

`content`

The builder closure that contains the child views. Each view in the closure implicitly maps to a cell in the grid.

Use this initializer to create a [`GridRow`](https://developer.apple.com/documentation/swiftui/gridrow) inside of a [`Grid`](https://developer.apple.com/documentation/swiftui/grid). Provide a content closure that defines the cells of the row, and optionally customize the vertical alignment of content within each cell. The following example customizes the vertical alignment of the cells in the first and third rows:

```
Grid(alignment: .trailing) {

    GridRow(alignment: .top) { // Use top vertical alignment.

        Text("Top")

        Color.red.frame(width: 1, height: 50)

        Color.blue.frame(width: 50, height: 1)

    }

    GridRow { // Use the default (center) alignment.

        Text("Center")

        Color.red.frame(width: 1, height: 50)

        Color.blue.frame(width: 50, height: 1)

    }

    GridRow(alignment: .bottom) { // Use bottom vertical alignment.

        Text("Bottom")

        Color.red.frame(width: 1, height: 50)

        Color.blue.frame(width: 50, height: 1)

    }

}
```

The example above specifies [`trailing`](https://developer.apple.com/documentation/swiftui/alignment/trailing) alignment for the grid, which is composed of [`center`](https://developer.apple.com/documentation/swiftui/verticalalignment/center) vertical alignment and [`trailing`](https://developer.apple.com/documentation/swiftui/horizontalalignment/trailing) horizontal alignment. The middle row relies on the center vertical alignment, but the other two rows specify custom vertical alignments:

![A grid with three rows and three columns. Scanning from top to bottom,](https://docs-assets.developer.apple.com/published/ec9fde5bb4fb93095ccbcd86323d1783/GridRow-init-1-iOS~dark%402x.png)

To override column alignment, use [`gridColumnAlignment(_:)`](https://developer.apple.com/documentation/swiftui/view/gridcolumnalignment\(_:\)). To override alignment for a single cell, use [`gridCellAnchor(_:)`](https://developer.apple.com/documentation/swiftui/view/gridcellanchor\(_:\)).

Current page is init(alignment:content:)