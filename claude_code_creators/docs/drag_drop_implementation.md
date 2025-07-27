# Drag and Drop Implementation Guide

## Overview

This document describes the drag-and-drop functionality implemented for the context items sidebar in the Claude Code Creators application.

## Architecture

### Frontend Components

1. **Stimulus Controllers**
   - `drag_drop_controller.js`: Main controller handling drag/drop logic
   - `context_sidebar_controller.js`: Existing controller for sidebar interactions

2. **Sortable.js Library**
   - Provides sortable list functionality
   - Handles drag animations and events
   - Supports group configurations for complex drag scenarios

### Backend Components

1. **Database Changes**
   - Added `position` integer column to `context_items` table
   - Added composite index on `[document_id, item_type, position]`

2. **Model Updates**
   - `ContextItem` model now includes position management
   - Auto-assigns position on creation
   - Added `ordered` scope for position-based sorting

3. **Controller Actions**
   - Added `reorder` action to `ContextItemsController`
   - Accepts array of item IDs and updates positions

## Implementation Details

### Drag and Drop Controller

```javascript
// Key features:
- Sortable lists with drag handles
- Drag from sidebar to Trix editor
- Visual feedback during drag operations
- Error handling and user feedback
```

### Data Flow

1. **Reordering within sidebar:**
   ```
   User drags item → Sortable.js updates DOM → 
   Controller sends AJAX request → Server updates positions
   ```

2. **Dragging to editor:**
   ```
   User drags item → DataTransfer stores content → 
   Drop on editor → Insert HTML at cursor → Show feedback
   ```

### Styling

Custom CSS provides:
- Ghost effects for dragged items
- Highlight states for drop zones
- Animated borders and transitions
- Responsive drag handles

## Usage

### For Users

1. **Reorder items:** Drag by the handle (≡) that appears on hover
2. **Insert into editor:** Drag any item and drop into the Trix editor
3. **Sort options:** Use "Manual Order" to respect custom positions

### For Developers

To add drag-drop to a new component:

```erb
<div data-controller="drag-drop"
     data-drag-drop-reorder-url-value="<%= reorder_path %>"
     data-drag-drop-editor-selector-value="trix-editor">
  <div data-drag-drop-target="list">
    <!-- Sortable items -->
  </div>
</div>
```

## Configuration Options

The drag-drop controller accepts these values:
- `reorderUrl`: Endpoint for saving new positions
- `documentId`: Current document ID
- `editorSelector`: CSS selector for drop target

## Security Considerations

- CSRF tokens included in reorder requests
- Authorization checked in controller actions
- Position updates use `update_column` for performance

## Performance Notes

- Positions updated in single transaction
- Minimal DOM manipulation during drag
- Debounced reorder requests (if needed)

## Browser Compatibility

Tested and working in:
- Chrome/Edge (latest)
- Firefox (latest)
- Safari (latest)

## Future Enhancements

Potential improvements:
- Drag multiple items simultaneously
- Keyboard shortcuts for reordering
- Undo/redo functionality
- Custom drag previews
- Touch device optimization