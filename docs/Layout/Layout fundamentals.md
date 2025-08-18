---
title: "Layout fundamentals"
source: "https://developer.apple.com/documentation/swiftui/layout-fundamentals"
author:
  - "[[Apple Developer Documentation]]"
published:
created: 2025-08-18
description: "Arrange views inside built-in layout containers like stacks and grids."
tags:
  - "clippings"
---
[Skip Navigation](https://developer.apple.com/documentation/swiftui/#app-main)

Arrange views inside built-in layout containers like stacks and grids.

## Overview

Use layout containers to arrange the elements of your user interface. Stacks and grids update and adjust the positions of the subviews they contain in response to changes in content or interface dimensions. You can nest layout containers inside other layout containers to any depth to achieve complex layout effects.

![](https://docs-assets.developer.apple.com/published/9fd862b8214f1de236f13a51187c257f/layout-fundamentals-hero%402x.png)

To finetune the position, alignment, and other elements of a layout that you build with layout container views, see [Layout adjustments](https://developer.apple.com/documentation/swiftui/layout-adjustments). To define custom layout containers, see [Custom layout](https://developer.apple.com/documentation/swiftui/custom-layout). For design guidance, see [Layout](https://developer.apple.com/design/Human-Interface-Guidelines/layout) in the Human Interface Guidelines.

## Topics

### Choosing a layout

[Picking container views for your content](https://developer.apple.com/documentation/swiftui/picking-container-views-for-your-content)

Build flexible user interfaces by using stacks, grids, lists, and forms.

### Statically arranging views in one dimension

[Building layouts with stack views](https://developer.apple.com/documentation/swiftui/building-layouts-with-stack-views)

Compose complex layouts from primitive container views.

[`structHStack`](https://developer.apple.com/documentation/swiftui/hstack)

A view that arranges its subviews in a horizontal line.

[`structVStack`](https://developer.apple.com/documentation/swiftui/vstack)

A view that arranges its subviews in a vertical line.

### Dynamically arranging views in one dimension

[Grouping data with lazy stack views](https://developer.apple.com/documentation/swiftui/grouping-data-with-lazy-stack-views)

Split content into logical sections inside lazy stack views.

[Creating performant scrollable stacks](https://developer.apple.com/documentation/swiftui/creating-performant-scrollable-stacks)

Display large numbers of repeated views efficiently with scroll views, stack views, and lazy stacks.

[`structLazyHStack`](https://developer.apple.com/documentation/swiftui/lazyhstack)

A view that arranges its children in a line that grows horizontally, creating items only as needed.

[`structLazyVStack`](https://developer.apple.com/documentation/swiftui/lazyvstack)

A view that arranges its children in a line that grows vertically, creating items only as needed.

[`structPinnedScrollableViews`](https://developer.apple.com/documentation/swiftui/pinnedscrollableviews)

A set of view types that may be pinned to the bounds of a scroll view.

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

[`funcgridColumnAlignment(HorizontalAlignment) -> someView`](https://developer.apple.com/documentation/swiftui/view/gridcolumnalignment\(_:\))

Overrides the default horizontal alignment of the grid column that the view appears in.

### Dynamically arranging views in two dimensions

[`structLazyHGrid`](https://developer.apple.com/documentation/swiftui/lazyhgrid)

A container view that arranges its child views in a grid that grows horizontally, creating items only as needed.

[`structLazyVGrid`](https://developer.apple.com/documentation/swiftui/lazyvgrid)

A container view that arranges its child views in a grid that grows vertically, creating items only as needed.

[`structGridItem`](https://developer.apple.com/documentation/swiftui/griditem)

A description of a row or a column in a lazy grid.

### Layering views

[Adding a background to your view](https://developer.apple.com/documentation/swiftui/adding-a-background-to-your-view)

Compose a background behind your view and extend it beyond the safe area insets.

[`structZStack`](https://developer.apple.com/documentation/swiftui/zstack)

A view that overlays its subviews, aligning them in both axes.

[`funczIndex(Double) -> someView`](https://developer.apple.com/documentation/swiftui/view/zindex\(_:\))

Controls the display order of overlapping views.

[`funcbackground<V>(alignment: Alignment, content: () -> V) -> someView`](https://developer.apple.com/documentation/swiftui/view/background\(alignment:content:\))

Layers the views that you specify behind this view.

[`funcbackground<S>(S, ignoresSafeAreaEdges: Edge.Set) -> someView`](https://developer.apple.com/documentation/swiftui/view/background\(_:ignoressafeareaedges:\))

Sets the view’s background to a style.

[`funcbackground(ignoresSafeAreaEdges: Edge.Set) -> someView`](https://developer.apple.com/documentation/swiftui/view/background\(ignoressafeareaedges:\))

Sets the view’s background to the default background style.

[`funcbackground(_:in:fillStyle:)`](https://developer.apple.com/documentation/swiftui/view/background\(_:in:fillstyle:\))

Sets the view’s background to an insettable shape filled with a style.

[`funcbackground(in:fillStyle:)`](https://developer.apple.com/documentation/swiftui/view/background\(in:fillstyle:\))

Sets the view’s background to an insettable shape filled with the default background style.

[`funcoverlay<V>(alignment: Alignment, content: () -> V) -> someView`](https://developer.apple.com/documentation/swiftui/view/overlay\(alignment:content:\))

Layers the views that you specify in front of this view.

[`funcoverlay<S>(S, ignoresSafeAreaEdges: Edge.Set) -> someView`](https://developer.apple.com/documentation/swiftui/view/overlay\(_:ignoressafeareaedges:\))

Layers the specified style in front of this view.

[`funcoverlay<S, T>(S, in: T, fillStyle: FillStyle) -> someView`](https://developer.apple.com/documentation/swiftui/view/overlay\(_:in:fillstyle:\))

Layers a shape that you specify in front of this view.

[`varbackgroundMaterial: Material?`](https://developer.apple.com/documentation/swiftui/environmentvalues/backgroundmaterial)

The material underneath the current view.

[`funccontainerBackground<S>(S, for: ContainerBackgroundPlacement) -> someView`](https://developer.apple.com/documentation/swiftui/view/containerbackground\(_:for:\))

Sets the container background of the enclosing container using a view.

[`funccontainerBackground<V>(for: ContainerBackgroundPlacement, alignment: Alignment, content: () -> V) -> someView`](https://developer.apple.com/documentation/swiftui/view/containerbackground\(for:alignment:content:\))

Sets the container background of the enclosing container using a view.

[`structContainerBackgroundPlacement`](https://developer.apple.com/documentation/swiftui/containerbackgroundplacement)

The placement of a container background.

### Automatically choosing the layout that fits

[`structViewThatFits`](https://developer.apple.com/documentation/swiftui/viewthatfits)

A view that adapts to the available space by providing the first child view that fits.

### Separators

[`structSpacer`](https://developer.apple.com/documentation/swiftui/spacer)

A flexible space that expands along the major axis of its containing stack layout, or on both axes if not contained in a stack.

[`structDivider`](https://developer.apple.com/documentation/swiftui/divider)

A visual element that can be used to separate other content.

## See Also

### View layout

[Layout adjustments](https://developer.apple.com/documentation/swiftui/layout-adjustments)

Make fine adjustments to alignment, spacing, padding, and other layout parameters.

[Custom layout](https://developer.apple.com/documentation/swiftui/custom-layout)

Place views in custom arrangements and create animated transitions between layout types.

[Lists](https://developer.apple.com/documentation/swiftui/lists)

Display a structured, scrollable column of information.

[Tables](https://developer.apple.com/documentation/swiftui/tables)

Display selectable, sortable data arranged in rows and columns.

[View groupings](https://developer.apple.com/documentation/swiftui/view-groupings)

Present views in different kinds of purpose-driven containers, like forms or control groups.

[Scroll views](https://developer.apple.com/documentation/swiftui/scroll-views)

Enable people to scroll to content that doesn’t fit in the current display.

Current page is Layout fundamentals