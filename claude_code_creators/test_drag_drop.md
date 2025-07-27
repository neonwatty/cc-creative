# Testing Drag and Drop Functionality

## Setup Complete

The drag-and-drop functionality has been implemented with the following features:

### 1. **Sortable.js Integration**
- Installed via npm and configured with importmap
- Items within the sidebar can be reordered by dragging

### 2. **Drag from Sidebar to Editor**
- Context items (snippets, drafts, versions) can be dragged from the sidebar
- Drop zones are highlighted when dragging
- Content is inserted at the cursor position in the Trix editor

### 3. **Visual Feedback**
- Ghost effect when dragging items
- Drop zone highlighting with animated border
- Success/error feedback on drop
- Drag handles appear on hover

### 4. **Backend Support**
- Added `position` field to context_items table
- Created `reorder` action in ContextItemsController
- Position is automatically set when creating new items

### 5. **Styling**
- Added CSS for drag states and animations
- Responsive hover effects
- Visual indicators for draggable items

## How to Test

1. Start the Rails server (already running on port 3001)
2. Navigate to: http://localhost:3001/documents/1/edit
3. You should see:
   - The document editor with Trix
   - A context sidebar on the right with test items

### Test Cases:

1. **Reorder Items in Sidebar**
   - Hover over any item to see the drag handle
   - Click and drag to reorder within the same tab
   - Release to save the new order

2. **Drag to Editor**
   - Click and drag any context item
   - Notice the editor highlights with a blue dashed border
   - Drop the item into the editor
   - The content should be inserted with formatting

3. **Sort Options**
   - Change the sort dropdown to "Manual Order"
   - This will respect the custom positions set by dragging

## Files Modified/Created:

1. **JavaScript Controllers:**
   - `/app/javascript/controllers/drag_drop_controller.js` (new)
   - Updated context_sidebar_controller.js

2. **Views:**
   - Updated `context_sidebar_component.html.erb`
   - Updated `_sidebar_item.html.erb` partial

3. **Backend:**
   - Added migration for position field
   - Updated ContextItem model
   - Added reorder action to controller
   - Updated routes

4. **Styling:**
   - Added drag/drop CSS to application.css

5. **Dependencies:**
   - Added sortablejs to package.json and importmap

## Next Steps:

If you need any adjustments or additional features:
- Custom drag preview
- Keyboard shortcuts for drag/drop
- Undo/redo functionality
- Different insertion formats
- Drag multiple items at once