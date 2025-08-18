---
title: "Layout adjustments"
source: "https://developer.apple.com/documentation/swiftui/layout-adjustments"
author:
  - "[[Apple Developer Documentation]]"
published:
created: 2025-08-18
description: "Make fine adjustments to alignment, spacing, padding, and other layout parameters."
tags:
  - "clippings"
---
[Skip Navigation](https://developer.apple.com/documentation/swiftui/#app-main)

Make fine adjustments to alignment, spacing, padding, and other layout parameters.

## Overview

Layout containers like stacks and grids provide a great starting point for arranging views in your app’s user interface. When you need to make fine adjustments, use layout view modifiers. You can adjust or constrain the size, position, and alignment of a view. You can also add padding around a view, and indicate how the view interacts with system-defined safe areas.

![](https://docs-assets.developer.apple.com/published/44eb8b59b2583dbb9feab193d65420ee/layout-adjustments-hero%402x.png)

To get started with a basic layout, see [Layout fundamentals](https://developer.apple.com/documentation/swiftui/layout-fundamentals). For design guidance, see [Layout](https://developer.apple.com/design/Human-Interface-Guidelines/layout) in the Human Interface Guidelines.

## Topics

### Finetuning a layout

[Laying out a simple view](https://developer.apple.com/documentation/swiftui/laying-out-a-simple-view)

Create a view layout by adjusting the size of views.

[Inspecting view layout](https://developer.apple.com/documentation/swiftui/inspecting-view-layout)

Determine the position and extent of a view using Xcode previews or by adding temporary borders.

### Adding padding around a view

[`funcpadding(_:)`](https://developer.apple.com/documentation/swiftui/view/padding\(_:\))

Adds a different padding amount to each edge of this view.

[`funcpadding(Edge.Set, CGFloat?) -> someView`](https://developer.apple.com/documentation/swiftui/view/padding\(_:_:\))

Adds an equal padding amount to specific edges of this view.

[`funcpadding3D(_:)`](https://developer.apple.com/documentation/swiftui/view/padding3d\(_:\))

Pads this view using the edge insets you specify.

[`funcpadding3D(Edge3D.Set, CGFloat?) -> someView`](https://developer.apple.com/documentation/swiftui/view/padding3d\(_:_:\))

Pads this view using the edge insets you specify.

[`funcscenePadding(Edge.Set) -> someView`](https://developer.apple.com/documentation/swiftui/view/scenepadding\(_:\))

Adds padding to the specified edges of this view using an amount that’s appropriate for the current scene.

[`funcscenePadding(ScenePadding, edges: Edge.Set) -> someView`](https://developer.apple.com/documentation/swiftui/view/scenepadding\(_:edges:\))

Adds a specified kind of padding to the specified edges of this view using an amount that’s appropriate for the current scene.

[`structScenePadding`](https://developer.apple.com/documentation/swiftui/scenepadding)

The padding used to space a view from its containing scene.

### Influencing a view’s size

[`funcframe(width: CGFloat?, height: CGFloat?, alignment: Alignment) -> someView`](https://developer.apple.com/documentation/swiftui/view/frame\(width:height:alignment:\))

Positions this view within an invisible frame with the specified size.

[`funcframe(depth: CGFloat?, alignment: DepthAlignment) -> someView`](https://developer.apple.com/documentation/swiftui/view/frame\(depth:alignment:\))

Positions this view within an invisible frame with the specified depth.

[`funcframe(minWidth: CGFloat?, idealWidth: CGFloat?, maxWidth: CGFloat?, minHeight: CGFloat?, idealHeight: CGFloat?, maxHeight: CGFloat?, alignment: Alignment) -> someView`](https://developer.apple.com/documentation/swiftui/view/frame\(minwidth:idealwidth:maxwidth:minheight:idealheight:maxheight:alignment:\))

Positions this view within an invisible frame having the specified size constraints.

[`funcframe(minDepth: CGFloat?, idealDepth: CGFloat?, maxDepth: CGFloat?, alignment: DepthAlignment) -> someView`](https://developer.apple.com/documentation/swiftui/view/frame\(mindepth:idealdepth:maxdepth:alignment:\))

Positions this view within an invisible frame having the specified depth constraints.

[`funccontainerRelativeFrame(Axis.Set, alignment: Alignment) -> someView`](https://developer.apple.com/documentation/swiftui/view/containerrelativeframe\(_:alignment:\))

Positions this view within an invisible frame with a size relative to the nearest container.

[`funccontainerRelativeFrame(Axis.Set, alignment: Alignment, (CGFloat, Axis) -> CGFloat) -> someView`](https://developer.apple.com/documentation/swiftui/view/containerrelativeframe\(_:alignment:_:\))

Positions this view within an invisible frame with a size relative to the nearest container.

[`funccontainerRelativeFrame(Axis.Set, count: Int, span: Int, spacing: CGFloat, alignment: Alignment) -> someView`](https://developer.apple.com/documentation/swiftui/view/containerrelativeframe\(_:count:span:spacing:alignment:\))

Positions this view within an invisible frame with a size relative to the nearest container.

[`funcfixedSize() -> someView`](https://developer.apple.com/documentation/swiftui/view/fixedsize\(\))

Fixes this view at its ideal size.

[`funcfixedSize(horizontal: Bool, vertical: Bool) -> someView`](https://developer.apple.com/documentation/swiftui/view/fixedsize\(horizontal:vertical:\))

Fixes this view at its ideal size in the specified dimensions.

[`funclayoutPriority(Double) -> someView`](https://developer.apple.com/documentation/swiftui/view/layoutpriority\(_:\))

Sets the priority by which a parent layout should apportion space to this child.

### Adjusting a view’s position

[Making fine adjustments to a view’s position](https://developer.apple.com/documentation/swiftui/making-fine-adjustments-to-a-view-s-position)

Shift the position of a view by applying the offset or position modifier.

[`funcposition(CGPoint) -> someView`](https://developer.apple.com/documentation/swiftui/view/position\(_:\))

Positions the center of this view at the specified point in its parent’s coordinate space.

[`funcposition(x: CGFloat, y: CGFloat) -> someView`](https://developer.apple.com/documentation/swiftui/view/position\(x:y:\))

Positions the center of this view at the specified coordinates in its parent’s coordinate space.

[`funcoffset(CGSize) -> someView`](https://developer.apple.com/documentation/swiftui/view/offset\(_:\))

Offset this view by the horizontal and vertical amount specified in the offset parameter.

[`funcoffset(x: CGFloat, y: CGFloat) -> someView`](https://developer.apple.com/documentation/swiftui/view/offset\(x:y:\))

Offset this view by the specified horizontal and vertical distances.

[`funcoffset(z: CGFloat) -> someView`](https://developer.apple.com/documentation/swiftui/view/offset\(z:\))

Brings a view forward in Z by the provided distance in points.

### Aligning views

[Aligning views within a stack](https://developer.apple.com/documentation/swiftui/aligning-views-within-a-stack)

Position views inside a stack using alignment guides.

[Aligning views across stacks](https://developer.apple.com/documentation/swiftui/aligning-views-across-stacks)

Create a custom alignment and use it to align views across multiple stacks.

[`funcalignmentGuide(_:computeValue:)`](https://developer.apple.com/documentation/swiftui/view/alignmentguide\(_:computevalue:\))

Sets the view’s horizontal alignment.

[`structAlignment`](https://developer.apple.com/documentation/swiftui/alignment)

An alignment in both axes.

[`structHorizontalAlignment`](https://developer.apple.com/documentation/swiftui/horizontalalignment)

An alignment position along the horizontal axis.

[`structVerticalAlignment`](https://developer.apple.com/documentation/swiftui/verticalalignment)

An alignment position along the vertical axis.

[`structDepthAlignment`](https://developer.apple.com/documentation/swiftui/depthalignment)

An alignment position along the depth axis.

[`protocolAlignmentID`](https://developer.apple.com/documentation/swiftui/alignmentid)

A type that you use to create custom alignment guides.

[`structViewDimensions`](https://developer.apple.com/documentation/swiftui/viewdimensions)

A view’s size and alignment guides in its own coordinate space.

[`structViewDimensions3D`](https://developer.apple.com/documentation/swiftui/viewdimensions3d)

A view’s 3D size and alignment guides in its own coordinate space.

[`structSpatialContainer`](https://developer.apple.com/documentation/swiftui/spatialcontainer)

A layout container that aligns overlapping content in 3D space.

Beta

### Setting margins

[`funccontentMargins(CGFloat, for: ContentMarginPlacement) -> someView`](https://developer.apple.com/documentation/swiftui/view/contentmargins\(_:for:\))

Configures the content margin for a provided placement.

[`funccontentMargins(_:_:for:)`](https://developer.apple.com/documentation/swiftui/view/contentmargins\(_:_:for:\))

Configures the content margin for a provided placement.

[`structContentMarginPlacement`](https://developer.apple.com/documentation/swiftui/contentmarginplacement)

The placement of margins.

### Staying in the safe areas

[`funcignoresSafeArea(SafeAreaRegions, edges: Edge.Set) -> someView`](https://developer.apple.com/documentation/swiftui/view/ignoressafearea\(_:edges:\))

Expands the safe area of a view.

[`funcsafeAreaInset(edge:alignment:spacing:content:)`](https://developer.apple.com/documentation/swiftui/view/safeareainset\(edge:alignment:spacing:content:\))

Shows the specified content beside the modified view.

[`funcsafeAreaPadding(_:)`](https://developer.apple.com/documentation/swiftui/view/safeareapadding\(_:\))

Adds the provided insets into the safe area of this view.

[`funcsafeAreaPadding(Edge.Set, CGFloat?) -> someView`](https://developer.apple.com/documentation/swiftui/view/safeareapadding\(_:_:\))

Adds the provided insets into the safe area of this view.

[`structSafeAreaRegions`](https://developer.apple.com/documentation/swiftui/safearearegions)

A set of symbolic safe area regions.

### Setting a layout direction

[`funclayoutDirectionBehavior(LayoutDirectionBehavior) -> someView`](https://developer.apple.com/documentation/swiftui/view/layoutdirectionbehavior\(_:\))

Sets the behavior of this view for different layout directions.

[`enumLayoutDirectionBehavior`](https://developer.apple.com/documentation/swiftui/layoutdirectionbehavior)

A description of what should happen when the layout direction changes.

[`varlayoutDirection: LayoutDirection`](https://developer.apple.com/documentation/swiftui/environmentvalues/layoutdirection)

The layout direction associated with the current environment.

[`enumLayoutDirection`](https://developer.apple.com/documentation/swiftui/layoutdirection)

A direction in which SwiftUI can lay out content.

[`structLayoutRotationUnaryLayout`](https://developer.apple.com/documentation/swiftui/layoutrotationunarylayout) Beta

### Reacting to interface characteristics

[`varisLuminanceReduced: Bool`](https://developer.apple.com/documentation/swiftui/environmentvalues/isluminancereduced)

A Boolean value that indicates whether the display or environment currently requires reduced luminance.

[`vardisplayScale: CGFloat`](https://developer.apple.com/documentation/swiftui/environmentvalues/displayscale)

The display scale of this environment.

[`varpixelLength: CGFloat`](https://developer.apple.com/documentation/swiftui/environmentvalues/pixellength)

The size of a pixel on the screen.

[`varhorizontalSizeClass: UserInterfaceSizeClass?`](https://developer.apple.com/documentation/swiftui/environmentvalues/horizontalsizeclass)

The horizontal size class of this environment.

[`varverticalSizeClass: UserInterfaceSizeClass?`](https://developer.apple.com/documentation/swiftui/environmentvalues/verticalsizeclass)

The vertical size class of this environment.

[`enumUserInterfaceSizeClass`](https://developer.apple.com/documentation/swiftui/userinterfacesizeclass)

A set of values that indicate the visual size available to the view.

### Accessing edges, regions, and layouts

[`enumEdge`](https://developer.apple.com/documentation/swiftui/edge)

An enumeration to indicate one edge of a rectangle.

[`enumEdge3D`](https://developer.apple.com/documentation/swiftui/edge3d)

An edge or face of a 3D volume.

[`enumHorizontalEdge`](https://developer.apple.com/documentation/swiftui/horizontaledge)

An edge on the horizontal axis.

[`enumVerticalEdge`](https://developer.apple.com/documentation/swiftui/verticaledge)

An edge on the vertical axis.

[`structEdgeInsets`](https://developer.apple.com/documentation/swiftui/edgeinsets)

The inset distances for the sides of a rectangle.

[`structEdgeInsets3D`](https://developer.apple.com/documentation/swiftui/edgeinsets3d)

The inset distances for the faces of a 3D volume.

## See Also

### View layout

[Layout fundamentals](https://developer.apple.com/documentation/swiftui/layout-fundamentals)

Arrange views inside built-in layout containers like stacks and grids.

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

Current page is Layout adjustments