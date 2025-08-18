---
title: "Grid"
source: "https://developer.apple.com/documentation/swiftui/grid"
author:
  - "[[Apple Developer Documentation]]"
published:
created: 2025-08-18
description: "A container view that arranges other views in a two dimensional layout."
tags:
  - "clippings"
---
[Skip Navigation](https://developer.apple.com/documentation/swiftui/#app-main)

A container view that arranges other views in a two dimensional layout.

```
@frozen
struct Grid<Content> where Content : View
```

## Overview

Create a two dimensional layout by initializing a `Grid` with a collection of [`GridRow`](https://developer.apple.com/documentation/swiftui/gridrow) structures. The first view in each grid row appears in the grid’s first column, the second view in the second column, and so on. The following example creates a grid with two rows and two columns:

```
Grid {

    GridRow {

        Text("Hello")

        Image(systemName: "globe")

    }

    GridRow {

        Image(systemName: "hand.wave")

        Text("World")

    }

}
```

A grid and its rows behave something like a collection of [`HStack`](https://developer.apple.com/documentation/swiftui/hstack) instances wrapped in a [`VStack`](https://developer.apple.com/documentation/swiftui/vstack). However, the grid handles row and column creation as a single operation, which applies alignment and spacing to cells, rather than first to rows and then to a column of unrelated rows. The grid produced by the example above demonstrates this:

![A screenshot of items arranged in a grid. The upper-left](https://docs-assets.developer.apple.com/published/e4c39b671e0abfa62bf89dd8a194e03f/Grid-1-iOS~dark%402x.png)

### Multicolumn cells

If you provide a view rather than a [`GridRow`](https://developer.apple.com/documentation/swiftui/gridrow) as an element in the grid’s content, the grid uses the view to create a row that spans all of the grid’s columns. For example, you can add a [`Divider`](https://developer.apple.com/documentation/swiftui/divider) between the rows of the previous example:

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

Because a divider takes as much horizontal space as its parent offers, the entire grid widens to fill the width offered by its parent view.

![A screenshot of items arranged in a grid. The upper-left](https://docs-assets.developer.apple.com/published/7b5ff8b453f028f94c55a242a7cf9bc7/Grid-2-iOS~dark%402x.png)

To prevent a flexible view from taking more space on a given axis than the other cells in a row or column require, add the [`gridCellUnsizedAxes(_:)`](https://developer.apple.com/documentation/swiftui/view/gridcellunsizedaxes\(_:\)) view modifier to the view:

```
Divider()

    .gridCellUnsizedAxes(.horizontal)
```

This restores the grid to the width that the text and images require:

![A screenshot of items arranged in a grid. The upper-left](https://docs-assets.developer.apple.com/published/51720a57791bbbbba0cc0c84b70f3d4a/Grid-3-iOS~dark%402x.png)

To make a cell span a specific number of columns rather than the whole grid, use the [`gridCellColumns(_:)`](https://developer.apple.com/documentation/swiftui/view/gridcellcolumns\(_:\)) modifier on a view that’s contained inside a [`GridRow`](https://developer.apple.com/documentation/swiftui/gridrow).

### Column count

The grid’s column count grows to handle the row with the largest number of columns. If you create rows with different numbers of columns, the grid adds empty cells to the trailing edge of rows that have fewer columns. The example below creates three rows with different column counts:

```
Grid {

    GridRow {

        Text("Row 1")

        ForEach(0..<2) { _ in Color.red }

    }

    GridRow {

        Text("Row 2")

        ForEach(0..<5) { _ in Color.green }

    }

    GridRow {

        Text("Row 3")

        ForEach(0..<4) { _ in Color.blue }

    }

}
```

The resulting grid has as many columns as the widest row, adding empty cells to rows that don’t specify enough views:

![A screenshot of a grid with three rows and six columns. The first](https://docs-assets.developer.apple.com/published/f58518fa453d139496b1015c772b91ab/Grid-4-iOS~dark%402x.png)

The grid sets the width of all the cells in a column to match the needs of column’s widest cell. In the example above, the width of the first column depends on the width of the widest [`Text`](https://developer.apple.com/documentation/swiftui/text) view that the column contains. The other columns, which contain flexible [`Color`](https://developer.apple.com/documentation/swiftui/color) views, share the remaining horizontal space offered by the grid’s parent view equally.

Similarly, the tallest cell in a row sets the height of the entire row. The cells in the first column of the grid above need only the height required for each string, but the [`Color`](https://developer.apple.com/documentation/swiftui/color) cells expand to equally share the total height available to the grid. As a result, the color cells determine the row heights.

### Cell spacing and alignment

You can control the spacing between cells in both the horizontal and vertical dimensions and set a default alignment for the content in all the grid cells when you initialize the grid using the [`init(alignment:horizontalSpacing:verticalSpacing:content:)`](https://developer.apple.com/documentation/swiftui/grid/init\(alignment:horizontalspacing:verticalspacing:content:\)) initializer. Consider a modified version of the previous example:

```
Grid(alignment: .bottom, horizontalSpacing: 1, verticalSpacing: 1) {

    // ...

}
```

This configuration causes all of the cells to use [`bottom`](https://developer.apple.com/documentation/swiftui/alignment/bottom) alignment — which only affects the text cells because the colors fill their cells completely — and it reduces the spacing between cells:

![A screenshot of a grid with three rows and six columns. The first](https://docs-assets.developer.apple.com/published/be4ae4bb1115b4b63db3a014b3058ce2/Grid-5-iOS~dark%402x.png)

You can override the alignment of specific cells or groups of cells. For example, you can change the horizontal alignment of the cells in a column by adding the [`gridColumnAlignment(_:)`](https://developer.apple.com/documentation/swiftui/view/gridcolumnalignment\(_:\)) modifier, or the vertical alignment of the cells in a row by configuring the row’s [`init(alignment:content:)`](https://developer.apple.com/documentation/swiftui/gridrow/init\(alignment:content:\)) initializer. You can also align a single cell with the [`gridCellAnchor(_:)`](https://developer.apple.com/documentation/swiftui/view/gridcellanchor\(_:\)) modifier.

### Performance considerations

A grid can size its rows and columns correctly because it renders all of its child views immediately. If your app exhibits poor performance when it first displays a large grid that appears inside a [`ScrollView`](https://developer.apple.com/documentation/swiftui/scrollview), consider switching to a [`LazyVGrid`](https://developer.apple.com/documentation/swiftui/lazyvgrid) or [`LazyHGrid`](https://developer.apple.com/documentation/swiftui/lazyhgrid) instead.

Lazy grids render their cells when SwiftUI needs to display them, rather than all at once. This reduces the initial cost of displaying a large scrollable grid that’s never fully visible, but also reduces the grid’s ability to optimally lay out cells. Switch to a lazy grid only if profiling your code shows a worthwhile performance improvement.

## Topics

### Creating a grid

[`init(alignment: Alignment, horizontalSpacing: CGFloat?, verticalSpacing: CGFloat?, content: () -> Content)`](https://developer.apple.com/documentation/swiftui/grid/init\(alignment:horizontalspacing:verticalspacing:content:\))

Creates a grid with the specified spacing, alignment, and child views.

## See Also

### Statically arranging views in two dimensions

[`structGridRow`](https://developer.apple.com/documentation/swiftui/gridrow)

A horizontal row in a two dimensional grid container.

[`funcgridCellColumns(Int) -> someView`](https://developer.apple.com/documentation/swiftui/view/gridcellcolumns\(_:\))

Tells a view that acts as a cell in a grid to span the specified number of columns.

[`funcgridCellAnchor(UnitPoint) -> someView`](https://developer.apple.com/documentation/swiftui/view/gridcellanchor\(_:\))

Specifies a custom alignment anchor for a view that acts as a grid cell.

[`funcgridCellUnsizedAxes(Axis.Set) -> someView`](https://developer.apple.com/documentation/swiftui/view/gridcellunsizedaxes\(_:\))

Asks grid layouts not to offer the view extra size in the specified axes.

[`funcgridColumnAlignment(HorizontalAlignment) -> someView`](https://developer.apple.com/documentation/swiftui/view/gridcolumnalignment\(_:\))

Overrides the default horizontal alignment of the grid column that the view appears in.

Current page is Grid