---
title: "gridCellColumns(_:)"
source: "https://developer.apple.com/documentation/swiftui/view/gridcellcolumns(_:)"
author:
  - "[[Apple Developer Documentation]]"
published:
created: 2025-08-18
description: "Tells a view that acts as a cell in a grid to span the specified number of columns."
tags:
  - "clippings"
---
[Skip Navigation](https://developer.apple.com/documentation/swiftui/view/#app-main)

## Parameters

`count`

The number of columns that the view should consume when placed in a grid row.

## Return Value

A view that occupies the specified number of columns in a grid row.

By default, each view that you put into the content closure of a [`GridRow`](https://developer.apple.com/documentation/swiftui/gridrow) corresponds to exactly one column of the grid. Apply the `gridCellColumns(_:)` modifier to a view that you want to span more than one column, as in the following example of a typical macOS configuration view:

```
Grid(alignment: .leadingFirstTextBaseline) {

    GridRow {

        Text("Regular font:")

            .gridColumnAlignment(.trailing)

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

            .gridCellColumns(2) // Span two columns.

    }

}
```

The [`Toggle`](https://developer.apple.com/documentation/swiftui/toggle) in the example above spans the column that contains the font names and the column that contains the buttons:

![A screenshot of a configuration view, arranged in a grid. The grid](https://docs-assets.developer.apple.com/published/bd1ffa0249aabf5f310bd86c87320ac1/View-gridCellColumns-1-macOS~dark%402x.png)

As a convenience you can cause a view to span all of the [`Grid`](https://developer.apple.com/documentation/swiftui/grid) columns by placing the view directly in the content closure of the [`Grid`](https://developer.apple.com/documentation/swiftui/grid), outside of a [`GridRow`](https://developer.apple.com/documentation/swiftui/gridrow), and omitting the modifier. To do the opposite and include more than one view in a cell, group the views using an appropriate layout container, like an [`HStack`](https://developer.apple.com/documentation/swiftui/hstack), so that they act as a single view.

## See Also

### Statically arranging views in two dimensions

[`structGrid`](https://developer.apple.com/documentation/swiftui/grid)

A container view that arranges other views in a two dimensional layout.

[`structGridRow`](https://developer.apple.com/documentation/swiftui/gridrow)

A horizontal row in a two dimensional grid container.

[`funcgridCellAnchor(UnitPoint) -> someView`](https://developer.apple.com/documentation/swiftui/view/gridcellanchor\(_:\))

Specifies a custom alignment anchor for a view that acts as a grid cell.

[`funcgridCellUnsizedAxes(Axis.Set) -> someView`](https://developer.apple.com/documentation/swiftui/view/gridcellunsizedaxes\(_:\))

Asks grid layouts not to offer the view extra size in the specified axes.

[`funcgridColumnAlignment(HorizontalAlignment) -> someView`](https://developer.apple.com/documentation/swiftui/view/gridcolumnalignment\(_:\))

Overrides the default horizontal alignment of the grid column that the view appears in.

Current page is gridCellColumns(\_:)