---
title: "gridCellUnsizedAxes(_:)"
source: "https://developer.apple.com/documentation/swiftui/view/gridcellunsizedaxes(_:)"
author:
  - "[[Apple Developer Documentation]]"
published:
created: 2025-08-18
description: "Asks grid layouts not to offer the view extra size in the specified axes."
tags:
  - "clippings"
---
[Skip Navigation](https://developer.apple.com/documentation/swiftui/view/#app-main)

## Parameters

`axes`

The dimensions in which the grid shouldn’t offer the view a share of any available space. This prevents a flexible view like a [`Spacer`](https://developer.apple.com/documentation/swiftui/spacer), [`Divider`](https://developer.apple.com/documentation/swiftui/divider), or [`Color`](https://developer.apple.com/documentation/swiftui/color) from defining the size of a row or column.

## Return Value

A view that doesn’t ask an enclosing grid for extra size in one or more axes.

Use this modifier to prevent a flexible view from taking more space on the specified axes than the other cells in a row or column require. For example, consider the following [`Grid`](https://developer.apple.com/documentation/swiftui/grid) that places a [`Divider`](https://developer.apple.com/documentation/swiftui/divider) between two rows of content:

```
Grid {

    GridRow {

        Text("Hello")

        Image(systemName: "globe")

    }

    Divider()

    GridRow {

        Image(systemName: "hand.wave")

        Text("World")

    }

}
```

The text and images all have ideal widths for their content. However, because a divider takes as much space as its parent offers, the grid fills the width of the display, expanding all the other cells to match:

![A screenshot of items arranged in a grid. The upper-left](https://docs-assets.developer.apple.com/published/4fa8531323252fc5d7af07feb3b1e2c1/View-gridCellUnsizedAxes-1-iOS~dark%402x.png)

You can prevent the grid from giving the divider more width than the other cells require by adding the modifier with the [`Axis.horizontal`](https://developer.apple.com/documentation/swiftui/axis/horizontal) parameter:

```
Divider()

    .gridCellUnsizedAxes(.horizontal)
```

This restores the grid to the width that it would have without the divider:

![A screenshot of items arranged in a grid. The upper-left](https://docs-assets.developer.apple.com/published/4e4c7e6860615cd268f87484e9d95b7a/View-gridCellUnsizedAxes-2-iOS~dark%402x.png)

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

[`funcgridColumnAlignment(HorizontalAlignment) -> someView`](https://developer.apple.com/documentation/swiftui/view/gridcolumnalignment\(_:\))

Overrides the default horizontal alignment of the grid column that the view appears in.

Current page is gridCellUnsizedAxes(\_:)