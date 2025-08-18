---
title: "Lists"
source: "https://developer.apple.com/documentation/swiftui/lists"
author:
  - "[[Apple Developer Documentation]]"
published:
created: 2025-08-18
description: "Display a structured, scrollable column of information."
tags:
  - "clippings"
---
[Skip Navigation](https://developer.apple.com/documentation/swiftui/#app-main)

Display a structured, scrollable column of information.

## Overview

Use a list to display a one-dimensional vertical collection of views.

![](https://docs-assets.developer.apple.com/published/15c88d97bce9de9704854a5490b6aee5/lists-hero%402x.png)

The list is a complex container type that automatically provides scrolling when it grows too large for the current display. You build a list by providing it with individual views for the rows in the list, or by using a [`ForEach`](https://developer.apple.com/documentation/swiftui/foreach) to enumerate a group of rows. You can also mix these strategies, blending any number of individual views and `ForEach` constructs.

Use view modifiers to configure the appearance and behavior of a list and its rows, headers, sections, and separators. For example, you can apply a style to the list, add swipe gestures to individual rows, or make the list refreshable with a pull-down gesture. You can also use the configuration associated with [Scroll views](https://developer.apple.com/documentation/swiftui/scroll-views) to control the list’s implicit scrolling behavior.

For design guidance, see [Lists and tables](https://developer.apple.com/design/Human-Interface-Guidelines/lists-and-tables) in the Human Interface Guidelines.

## Topics

### Creating a list

[Displaying data in lists](https://developer.apple.com/documentation/swiftui/displaying-data-in-lists)

Visualize collections of data with platform-appropriate appearance.

[`structList`](https://developer.apple.com/documentation/swiftui/list)

A container that presents rows of data arranged in a single column, optionally providing the ability to select one or more members.

[`funclistStyle<S>(S) -> someView`](https://developer.apple.com/documentation/swiftui/view/liststyle\(_:\))

Sets the style for lists within this view.

### Disclosing information progressively

[`structOutlineGroup`](https://developer.apple.com/documentation/swiftui/outlinegroup)

A structure that computes views and disclosure groups on demand from an underlying collection of tree-structured, identified data.

[`structDisclosureGroup`](https://developer.apple.com/documentation/swiftui/disclosuregroup)

A view that shows or hides another content view, based on the state of a disclosure control.

[`funcdisclosureGroupStyle<S>(S) -> someView`](https://developer.apple.com/documentation/swiftui/view/disclosuregroupstyle\(_:\))

Sets the style for disclosure groups within this view.

### Configuring a list’s layout

[`funclistRowInsets(EdgeInsets?) -> someView`](https://developer.apple.com/documentation/swiftui/view/listrowinsets\(_:\))

Applies an inset to the rows in a list.

[`vardefaultMinListRowHeight: CGFloat`](https://developer.apple.com/documentation/swiftui/environmentvalues/defaultminlistrowheight)

The default minimum height of rows in a list.

[`funclistRowSpacing(CGFloat?) -> someView`](https://developer.apple.com/documentation/swiftui/view/listrowspacing\(_:\))

Sets the vertical spacing between two adjacent rows in a List.

[`funclistSectionSpacing(_:)`](https://developer.apple.com/documentation/swiftui/view/listsectionspacing\(_:\))

Sets the spacing between adjacent sections in a [`List`](https://developer.apple.com/documentation/swiftui/list) to a custom value.

[`structListSectionSpacing`](https://developer.apple.com/documentation/swiftui/listsectionspacing)

The spacing options between two adjacent sections in a list.

[`funclistSectionMargins(Edge.Set, CGFloat?) -> someView`](https://developer.apple.com/documentation/swiftui/view/listsectionmargins\(_:_:\))

Set the section margins for the specific edges.

Beta

### Configuring rows

[`funclistItemTint(_:)`](https://developer.apple.com/documentation/swiftui/view/listitemtint\(_:\))

Sets a fixed tint color for content in a list.

[`structListItemTint`](https://developer.apple.com/documentation/swiftui/listitemtint)

A tint effect configuration that you can apply to content in a list.

### Configuring headers

[`enumProminence`](https://developer.apple.com/documentation/swiftui/prominence)

A type indicating the prominence of a view hierarchy.

### Configuring separators

[`funclistRowSeparatorTint(Color?, edges: VerticalEdge.Set) -> someView`](https://developer.apple.com/documentation/swiftui/view/listrowseparatortint\(_:edges:\))

Sets the tint color associated with a row.

[`funclistSectionSeparatorTint(Color?, edges: VerticalEdge.Set) -> someView`](https://developer.apple.com/documentation/swiftui/view/listsectionseparatortint\(_:edges:\))

Sets the tint color associated with a section.

[`funclistRowSeparator(Visibility, edges: VerticalEdge.Set) -> someView`](https://developer.apple.com/documentation/swiftui/view/listrowseparator\(_:edges:\))

Sets the display mode for the separator associated with this specific row.

[`funclistSectionSeparator(Visibility, edges: VerticalEdge.Set) -> someView`](https://developer.apple.com/documentation/swiftui/view/listsectionseparator\(_:edges:\))

Sets whether to hide the separator associated with a list section.

### Configuring backgrounds

[`funclistRowBackground<V>(V?) -> someView`](https://developer.apple.com/documentation/swiftui/view/listrowbackground\(_:\))

Places a custom background view behind a list row item.

[`funcalternatingRowBackgrounds(AlternatingRowBackgroundBehavior) -> someView`](https://developer.apple.com/documentation/swiftui/view/alternatingrowbackgrounds\(_:\))

Overrides whether lists and tables in this view have alternating row backgrounds.

[`structAlternatingRowBackgroundBehavior`](https://developer.apple.com/documentation/swiftui/alternatingrowbackgroundbehavior)

The styling of views with respect to alternating row backgrounds.

[`varbackgroundProminence: BackgroundProminence`](https://developer.apple.com/documentation/swiftui/environmentvalues/backgroundprominence)

The prominence of the background underneath views associated with this environment.

[`structBackgroundProminence`](https://developer.apple.com/documentation/swiftui/backgroundprominence)

The prominence of backgrounds underneath other views.

### Displaying a badge on a list item

[`funcbadge(_:)`](https://developer.apple.com/documentation/swiftui/view/badge\(_:\))

Generates a badge for the view from an integer value.

[`funcbadgeProminence(BadgeProminence) -> someView`](https://developer.apple.com/documentation/swiftui/view/badgeprominence\(_:\))

Specifies the prominence of badges created by this view.

[`varbadgeProminence: BadgeProminence`](https://developer.apple.com/documentation/swiftui/environmentvalues/badgeprominence)

The prominence to apply to badges associated with this environment.

[`structBadgeProminence`](https://developer.apple.com/documentation/swiftui/badgeprominence)

The visual prominence of a badge.

[`funcswipeActions<T>(edge: HorizontalEdge, allowsFullSwipe: Bool, content: () -> T) -> someView`](https://developer.apple.com/documentation/swiftui/view/swipeactions\(edge:allowsfullswipe:content:\))

Adds custom swipe actions to a row in a list.

[`funcselectionDisabled(Bool) -> someView`](https://developer.apple.com/documentation/swiftui/view/selectiondisabled\(_:\))

Adds a condition that controls whether users can select this view.

[`funclistRowHoverEffect(HoverEffect?) -> someView`](https://developer.apple.com/documentation/swiftui/view/listrowhovereffect\(_:\))

Requests that the containing list row use the provided hover effect.

[`funclistRowHoverEffectDisabled(Bool) -> someView`](https://developer.apple.com/documentation/swiftui/view/listrowhovereffectdisabled\(_:\))

Requests that the containing list row have its hover effect disabled.

### Refreshing a list’s content

[`funcrefreshable(action: () async -> Void) -> someView`](https://developer.apple.com/documentation/swiftui/view/refreshable\(action:\))

Marks this view as refreshable.

[`varrefresh: RefreshAction?`](https://developer.apple.com/documentation/swiftui/environmentvalues/refresh)

A refresh action stored in a view’s environment.

[`structRefreshAction`](https://developer.apple.com/documentation/swiftui/refreshaction)

An action that initiates a refresh operation.

### Editing a list

[`funcmoveDisabled(Bool) -> someView`](https://developer.apple.com/documentation/swiftui/view/movedisabled\(_:\))

Adds a condition for whether the view’s view hierarchy is movable.

[`funcdeleteDisabled(Bool) -> someView`](https://developer.apple.com/documentation/swiftui/view/deletedisabled\(_:\))

Adds a condition for whether the view’s view hierarchy is deletable.

[`vareditMode: Binding<EditMode>?`](https://developer.apple.com/documentation/swiftui/environmentvalues/editmode)

An indication of whether the user can edit the contents of a view associated with this environment.

[`enumEditMode`](https://developer.apple.com/documentation/swiftui/editmode)

A mode that indicates whether the user can edit a view’s content.

[`structEditActions`](https://developer.apple.com/documentation/swiftui/editactions)

A set of edit actions on a collection of data that a view can offer to a user.

[`structEditableCollectionContent`](https://developer.apple.com/documentation/swiftui/editablecollectioncontent)

An opaque wrapper view that adds editing capabilities to a row in a list.

[`structIndexedIdentifierCollection`](https://developer.apple.com/documentation/swiftui/indexedidentifiercollection)

A collection wrapper that iterates over the indices and identifiers of a collection together.

### Configuring a section index

[`funclistSectionIndexVisibility(Visibility) -> someView`](https://developer.apple.com/documentation/swiftui/view/listsectionindexvisibility\(_:\))

Changes the visibility of the list section index.

Beta

[`funcsectionIndexLabel(_:)`](https://developer.apple.com/documentation/swiftui/view/sectionindexlabel\(_:\))

Sets the label that is used in a section index to point to this section, typically only a single character long.

Beta

## See Also

### View layout

[Layout fundamentals](https://developer.apple.com/documentation/swiftui/layout-fundamentals)

Arrange views inside built-in layout containers like stacks and grids.

[Layout adjustments](https://developer.apple.com/documentation/swiftui/layout-adjustments)

Make fine adjustments to alignment, spacing, padding, and other layout parameters.

[Custom layout](https://developer.apple.com/documentation/swiftui/custom-layout)

Place views in custom arrangements and create animated transitions between layout types.

[Tables](https://developer.apple.com/documentation/swiftui/tables)

Display selectable, sortable data arranged in rows and columns.

[View groupings](https://developer.apple.com/documentation/swiftui/view-groupings)

Present views in different kinds of purpose-driven containers, like forms or control groups.

[Scroll views](https://developer.apple.com/documentation/swiftui/scroll-views)

Enable people to scroll to content that doesn’t fit in the current display.

Current page is Lists