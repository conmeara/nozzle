---
title: "init(alignment:horizontalSpacing:verticalSpacing:content:)"
source: "https://developer.apple.com/documentation/swiftui/grid/init(alignment:horizontalspacing:verticalspacing:content:)"
author:
  - "[[Apple Developer Documentation]]"
published:
created: 2025-08-18
description: "Creates a grid with the specified spacing, alignment, and child views."
tags:
  - "clippings"
---
[Skip Navigation](https://developer.apple.com/documentation/swiftui/grid/#app-main)

## Parameters

`alignment`

The guide for aligning the child views within the space allocated for a given cell. The default is [`center`](https://developer.apple.com/documentation/swiftui/alignment/center).

`horizontalSpacing`

The horizontal distance between each cell, given in points. The value is `nil` by default, which results in a default distance between cells that’s appropriate for the platform.

`verticalSpacing`

The vertical distance between each cell, given in points. The value is `nil` by default, which results in a default distance between cells that’s appropriate for the platform.

`content`

A closure that creates the grid’s rows.

Use this initializer to create a [`Grid`](https://developer.apple.com/documentation/swiftui/grid). Provide a content closure that defines the rows of the grid, and optionally customize the spacing between cells and the alignment of content within each cell. The following example customizes the spacing between cells:

```
Grid(horizontalSpacing: 30, verticalSpacing: 30) {

    ForEach(0..<5) { row in

        GridRow {

            ForEach(0..<5) { column in

                Text("(\(column), \(row))")

            }

        }

    }

}
```

You can list rows and the cells within rows directly, or you can use a [`ForEach`](https://developer.apple.com/documentation/swiftui/foreach) structure to generate either, as the example above does:

![A screenshot of a grid that contains five rows and five columns.](https://docs-assets.developer.apple.com/published/4bf5b54dd58d8c37915674b5d747201f/Grid-init-1-iOS~dark%402x.png)

By default, the grid’s alignment value applies to all of the cells in the grid. However, you can also change the alignment for particular cells or groups of cells:

- Override the vertical alignment for the cells in a row by specifying a [`VerticalAlignment`](https://developer.apple.com/documentation/swiftui/verticalalignment) parameter to the corresponding row’s [`init(alignment:content:)`](https://developer.apple.com/documentation/swiftui/gridrow/init\(alignment:content:\)) initializer.
- Override the horizontal alignment for the cells in a column by adding a [`gridColumnAlignment(_:)`](https://developer.apple.com/documentation/swiftui/view/gridcolumnalignment\(_:\)) view modifier to exactly one of the cells in the column, and specifying a [`HorizontalAlignment`](https://developer.apple.com/documentation/swiftui/horizontalalignment) parameter.
- Specify a custom alignment anchor for a particular cell by using the [`gridCellAnchor(_:)`](https://developer.apple.com/documentation/swiftui/view/gridcellanchor\(_:\)) modifier on the cell’s view.

Current page is init(alignment:horizontalSpacing:verticalSpacing:content:)