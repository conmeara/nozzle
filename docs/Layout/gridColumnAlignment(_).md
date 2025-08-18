---
title: "gridColumnAlignment(_:)"
source: "https://developer.apple.com/documentation/swiftui/view/gridcolumnalignment(_:)"
author:
  - "[[Apple Developer Documentation]]"
published:
created: 2025-08-18
description: "Overrides the default horizontal alignment of the grid column that the view appears in."
tags:
  - "clippings"
---
[Skip Navigation](https://developer.apple.com/documentation/swiftui/view/#app-main)

## Parameters

`guide`

The [`HorizontalAlignment`](https://developer.apple.com/documentation/swiftui/horizontalalignment) guide to use for the grid column that the view appears in.

## Return Value

A view that uses the specified horizontal alignment, and that causes all cells in the same column of a grid to use the same alignment.

You set a default alignment for the cells in a grid in both vertical and horizontal dimensions when you create the grid with the [`init(alignment:horizontalSpacing:verticalSpacing:content:)`](https://developer.apple.com/documentation/swiftui/grid/init\(alignment:horizontalspacing:verticalspacing:content:\)) initializer. However, you can use the `gridColumnAlignment(_:)` modifier to override the horizontal alignment of a column within the grid. The following example sets a grid’s alignment to [`leadingFirstTextBaseline`](https://developer.apple.com/documentation/swiftui/alignment/leadingfirsttextbaseline), and then sets the first column to use [`trailing`](https://developer.apple.com/documentation/swiftui/horizontalalignment/trailing) alignment:

```
Grid(alignment: .leadingFirstTextBaseline) {

    GridRow {

        Text("Regular font:")

            .gridColumnAlignment(.trailing) // Align the entire first column.

        Text("Helvetica 12")

        Button("Select...") { }

    }

    GridRow {

        Text("Fixed-width font:")

        Text("Menlo Regular 11")

        Button("Select...") { }

    }

    GridRow {

        Color.clear

            .gridCellUnsizedAxes([.vertical, .horizontal])

        Toggle("Use fixed-width font for new documents", isOn: $isOn)

            .gridCellColumns(2)

    }

}
```

This creates the layout of a typical macOS configuration view, with the trailing edge of the first column flush with the leading edge of the second column:

![A screenshot of a configuration view, arranged in a grid. The grid](https://docs-assets.developer.apple.com/published/bd1ffa0249aabf5f310bd86c87320ac1/View-gridColumnAlignment-1-macOS~dark%402x.png)

Add the modifier to only one cell in a column. The grid automatically aligns all cells in that column the same way. You get undefined behavior if you apply different alignments to different cells in the same column.

To override row alignment, see [`init(alignment:content:)`](https://developer.apple.com/documentation/swiftui/gridrow/init\(alignment:content:\)). To override alignment for a single cell, see [`gridCellAnchor(_:)`](https://developer.apple.com/documentation/swiftui/view/gridcellanchor\(_:\)).

## See Also

### Statically arranging views in two dimensions

[`structGrid`](https://developer.apple.com/documentation/swiftui/grid)

A container view that arranges other views in a two dimensional layout.

[`structGridRow`](https://developer.apple.com/documentation/swiftui/gridrow)

A horizontal row in a two dimensional grid container.

[`funcgridCellColumns(Int) -> someView`](https://developer.apple.com/documentation/swiftui/view/gridcellcolumns\(_:\))

Tells a view that acts as a cell in a grid to span the specified number of columns.

[`funcgridCellAnchor(UnitPoint) -> someView`](https://developer.apple.com/documentation/swiftui/view/gridcellanchor\(_:\))

Specifies a custom alignment anchor for a view that acts as a grid cell.

[`funcgridCellUnsizedAxes(Axis.Set) -> someView`](https://developer.apple.com/documentation/swiftui/view/gridcellunsizedaxes\(_:\))

Asks grid layouts not to offer the view extra size in the specified axes.

Current page is gridColumnAlignment(\_:)