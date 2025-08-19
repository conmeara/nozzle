# UI Redesign Session - Preview Pane Implementation

This document details all changes made during the UI redesign prototyping session to implement a Raycast-style preview pane and modernize the input interface.

## Overview

The session focused on:
1. Adding a fixed-width preview pane to the right side of the interface
2. Redesigning the unified input field to be more minimal and Spotlight-like
3. Adding white tab buttons for UI categorization
4. Implementing proper glass effects and transparency

## Architecture Changes

### Core Design Decisions

1. **Fixed Width Over Resizable**: Initially attempted resizable dividers, but NSPanel architecture conflicts with drag gestures caused window movement instead of pane resizing. Simplified to fixed 400px width.

2. **Glass Effects**: Implemented consistent glass/transparency throughout the interface using SwiftUI's `.regularMaterial` and transparency effects.

3. **Spotlight-Style Layout**: Reorganized input area to match modern macOS Spotlight interface patterns.

## Starting Point

Our session began after commit `d119521` which had just added mode-specific icons to the input field. The `UnifiedInputFieldView` at this point had:
- HStack layout with search/plus icons inline
- Microphone button in prompt mode
- Clear button functionality  
- VStack wrapper with bottom divider line
- Dynamic height calculation (25-80px)
- Complex padding and animation logic

## File Changes

### 1. ContentView.swift (`/nozzle/Views/ContentView.swift`)

**Major Structural Changes:**
- Redesigned main layout from complex nested stacks to clean HStack
- Added preview pane as conditional right panel
- Moved input controls to tab row area
- Added white tab buttons for UI. We will add the backend later but this will allow us to have multiple pages for clipboard or notes or other folders for that list view.
- Preview pane copies the original popup UI but brings it into a pane

**Key Implementation Details:**

```swift
// Main content area - simplified layout
HStack(spacing: 0) {
  // History list
  HistoryListView(...)
  .frame(minWidth: 300)
  
  // Preview pane (conditional with fixed width)
  if appState.showPreviewPane {
    Divider()
    
    VStack {
      // Preview content implementation
    }
    .frame(width: 400) // Fixed width for NSPanel simplicity
  }
}
```

**Preview Pane Content Structure:**
- Image preview with aspect ratio fitting
- Text content with proper wrapping
- Metadata section (application, copy times, copy count)
- Keyboard shortcuts reference
- Placeholder state for no selection

**Tab Button Implementation:**
```swift
// Controls and tab buttons row
HStack(spacing: 6) {
  // Mode icon (search or plus)
  // Microphone button
  // Category tabs ((#), Clipboard, +)
  // Clear button (conditional)
}
```

**Added TabButton Component:**
```swift
struct TabButton: View {
  let title: String
  let isSelected: Bool
  
  var body: some View {
    Button(action: {}) {
      Text(title)
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(isSelected ? .primary : .secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
          RoundedRectangle(cornerRadius: 4)
            .fill(isSelected ? Color.white : Color.white.opacity(0.6))
        )
    }
    .buttonStyle(PlainButtonStyle())
  }
}
```

### 2. UnifiedInputFieldView.swift (`/nozzle/Views/UnifiedInputFieldView.swift`)

**Complete Redesign:**
- Removed all embedded controls (moved to tab row)
- Added multi-line support with full text editing (starts with one line, can grow to 10 - lines and more with scrolling)
- Implemented full transparency
- Search mode always animates back to a single line with magnify glass next to text

**Evolution Path:**
1. **Initial**: HStack with icons and controls inline
2. **Two-tier**: Icons above, text input below
3. **Glass background**: Added `.regularMaterial` background
4. **Transparent**: Removed all backgrounds and borders
5. **Final**: Full-width transparent field with multi-line support

**Final Implementation:**
```swift
var body: some View {
  TextField(placeholderText, text: $query, axis: .vertical)
    .textFieldStyle(.plain)
    .focused($isFocused)
    .disableAutocorrection(true)
    .lineLimit(1...4)
    .font(.system(size: 14))
    .onSubmit {
      appState.select()
    }
  .padding(.horizontal, 8)
  .padding(.vertical, 4)
  .animation(.easeInOut(duration: 0.15), value: isSearchMode)
}
```

### 3. AppState.swift (`/nozzle/Observables/AppState.swift`)

**Preview Pane State Management:**
```swift
// Preview pane state (simple toggle with fixed width)
var showPreviewPane: Bool {
  didSet {
    Defaults[.showPreviewPane] = showPreviewPane
  }
}

var previewItem: HistoryItemDecorator? {
  return history.selectedItem
}
```

**Key Changes:**
- Added `showPreviewPane` boolean property
- Added computed `previewItem` property
- Integrated with UserDefaults for state persistence
- Removed any resizing-related properties, since you cant properly resize a panel within NSPanel



### 6. Defaults.Keys+Names.swift (`/nozzle/Extensions/Defaults.Keys+Names.swift`)

**Added Preview Pane Setting:**
```swift
static let showPreviewPane = Key<Bool>("showPreviewPane", default: true)
```

**Purpose:** Persists preview pane visibility state across app sessions.

Add settings for preview pane width (3 options)

### 7. HistoryItemView.swift (`/nozzle/Views/HistoryItemView.swift`)

**Removed Preview Popover Integration:**
```swift



// REMOVED: Popover preview functionality  
.popover(isPresented: $item.showPreview, arrowEdge: .trailing) {
  PreviewItemView(item: item)
}
```

**Simplified Click Handling:**
- Removed popover preview trigger (replaced by fixed preview pane)

Change default shortcut from option-space to control-space


### 9. ListItemView.swift (`/nozzle/Views/ListItemView.swift`)

**Minor Layout Adjustments:**
- Updated for compatibility with new preview pane integration
- Maintained existing functionality while working with simplified parent layouts

## Design Iterations and Key Decisions

### Preview Pane Width Evolution
1. **300px**: Initial implementation
2. **400px**: Final size for better content visibility

### Resizing Attempts and Abandonment
1. **Initial Goal**: Resizable preview pane with drag handle
2. **Implementation Issues**: NSPanel drag conflicts caused window movement
3. **Attempted Solutions**: 
   - `highPriorityGesture`
   - Global coordinate space
   - NSViewRepresentable wrappers
4. **Final Decision**: Fixed width for simplicity and reliability

### Glass Effects Implementation
- Used `.regularMaterial` for subtle glass effects
- Applied to input field temporarily (later removed for full transparency)
- Maintained throughout preview pane content areas

## UI Components Added

### TabButton Component
- **Location**: Inline within ContentView.swift
- **Purpose**: Spotlight-style category buttons
- **Features**: 
  - White background with opacity variations
  - Selection state support
  - Rounded corners (4px radius)
  - Compact 11pt font

## Key Technical Patterns

### State Management
- Boolean toggle for preview pane visibility
- UserDefaults integration for persistence
- Computed properties for preview content
- Observable pattern for UI updates

### Layout Architecture
- HStack for main content split
- Conditional rendering for preview pane
- Fixed width frames for NSPanel compatibility
- Minimal padding and spacing

### Animation and Transitions
- easeInOut for mode transitions
- Smooth preview pane show/hide
- Icon transition animations for mode switching


## File Summary

**Modified Files:**
- `nozzle/Views/ContentView.swift` - Major layout restructure and preview pane
- `nozzle/Views/UnifiedInputFieldView.swift` - Complete redesign to minimal field
- `nozzle/Observables/AppState.swift` - Preview pane state management
- `nozzle/AppDelegate.swift` - Window sizing calculations
- `nozzle/FloatingPanel.swift` - Dynamic width handling
- `nozzle/Extensions/Defaults.Keys+Names.swift` - Preview pane setting

**New Files Created and Abandoned:**
- `nozzle/Views/PreviewPaneView.swift` - Standalone preview component (later integrated into ContentView)
- `nozzle/Views/ResizableDivider.swift` - Custom resizable divider (abandoned due to NSPanel conflicts)

**Additional Files Modified Not Initially Documented:**
- `nozzle/Views/HistoryItemView.swift` - Removed popover preview functionality and copy button area geometry
- `nozzle/Views/HistoryListView.swift` - Simplified layout, removed complex pinned items positioning
- `nozzle/Views/ListItemView.swift` - Minor layout adjustments for new preview pane integration

### Key Baseline vs Final Comparison

**UnifiedInputFieldView Evolution:**
- **Before**: Complex VStack with HStack, dynamic height (25-80px), bottom divider, inline controls
- **After**: Simple TextField, fixed padding (8px/4px), no background, full transparency, 1-4 line limit

**ContentView Layout:**
- **Before**: Complex nested layout with separate pinned/unpinned sections
- **After**: Clean HStack with conditional preview pane, integrated tab controls

**Preview Functionality:**
- **Before**: Popover-based preview on hover with complex timing
- **After**: Fixed right-panel preview with immediate selection response

This implementation provides a solid foundation for a modern, Raycast-style interface while respecting the constraints of the NSPanel architecture. The abandoned resizable divider approach and the files created during iteration demonstrate the exploratory nature of the session and the challenges of working within NSPanel limitations.