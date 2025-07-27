# ContextItemPreviewComponent

A ViewComponent for displaying context item previews in a modal dialog. This component supports different content types, provides JavaScript interactions via Stimulus, and includes comprehensive security features.

## Features

- **Multiple Content Types**: Automatically detects and renders plain text, markdown, and code content
- **Security**: Content sanitization to prevent XSS attacks
- **Accessibility**: Full keyboard navigation and screen reader support
- **JavaScript Integration**: Stimulus controller for modal interactions
- **Customizable Actions**: Slot-based action buttons
- **Syntax Highlighting**: Preparation for code syntax highlighting
- **Responsive Design**: Mobile-friendly modal layout

## Basic Usage

```erb
<!-- Simple usage -->
<%= context_item_preview_modal(@context_item) %>

<!-- Usage with custom actions -->
<%= context_item_preview_modal(@context_item) do |component| %>
  <% component.with_primary_action do %>
    <button type="button" class="btn-primary" data-action="click->context-item-preview#insertContent">
      Insert into Editor
    </button>
  <% end %>
  
  <% component.with_secondary_action do %>
    <button type="button" class="btn-secondary" data-action="click->custom-handler#editItem">
      Edit
    </button>
  <% end %>
<% end %>
```

## Helper Methods

The component includes several helper methods in `ContextItemsHelper`:

### `context_item_preview_modal(context_item, options = {}, &block)`

Renders the complete preview modal component.

### `context_item_preview_button(context_item, text: nil, **options)`

Creates a button that opens the preview modal.

### `context_item_card(context_item, options = {})`

Renders a compact context item card with preview capability.

### `context_item_content_type(context_item)`

Returns a human-readable content type description.

### `syntax_language_indicator(context_item)`

Renders a language indicator for code content.

## Content Type Detection

The component automatically detects content types:

### Code Content
- Fenced code blocks with language specifiers
- Common programming keywords (def, class, function, etc.)
- Code-like patterns with braces and semicolons
- Metadata specifying content_type as 'code'

### Markdown Content
- Headers (#, ##, ###)
- Bold text (**text**)
- Links ([text](url))
- Lists (-, *, +)
- Metadata specifying content_type as 'markdown'

### Plain Text
- Default fallback for content that doesn't match code or markdown patterns

## JavaScript API

The Stimulus controller provides several features:

### Data Attributes

```html
data-controller="context-item-preview"
data-context-item-preview-id-value="123"
data-context-item-preview-type-value="snippet"
data-context-item-preview-content-type-value="code"
data-context-item-preview-modal-id-value="context-item-preview-123"
```

### Events

The component dispatches custom events:

```javascript
// When content is inserted
document.addEventListener('context-item-preview:insert', function(event) {
  const { content, contextItemId, itemType, contentType } = event.detail;
  // Handle content insertion
});

// When content is copied
document.addEventListener('context-item-preview:copied', function(event) {
  const { contextItemId } = event.detail;
  // Handle copy feedback
});

// When modal is closed
document.addEventListener('context-item-preview:closed', function(event) {
  const { contextItemId } = event.detail;
  // Handle cleanup
});
```

### Methods

```javascript
// Show modal programmatically
function showContextItemPreview(contextItemId) {
  const modal = document.querySelector(`[data-context-item-preview-id-value="${contextItemId}"]`);
  if (modal) {
    modal.classList.remove('hidden');
  }
}
```

## Trix Editor Integration

The component automatically integrates with Trix editors:

```javascript
// Content insertion
const trixEditor = document.querySelector('trix-editor');
if (trixEditor && trixEditor.editor) {
  trixEditor.editor.insertString(content);
}
```

## Styling

The component uses Tailwind CSS classes and includes custom CSS for:

- Content type specific styling
- Syntax highlighting preparation
- Modal animations
- Mobile responsiveness

### CSS Classes

- `.context-item-preview-modal` - Main modal container
- `.markdown-content` - Applied to markdown content
- `.code-content` - Applied to code content  
- `.plain-text-content` - Applied to plain text content
- `.syntax-ready` - Added to code blocks ready for highlighting

## Security Features

### Content Sanitization

- **Markdown**: Allows safe HTML tags, removes script tags and dangerous attributes
- **Code**: HTML-escaped to prevent XSS while preserving syntax highlighting capability
- **Plain Text**: Basic sanitization and formatting

### Allowed HTML Tags

For markdown content, only these tags are allowed:
- Text formatting: `p`, `br`, `strong`, `em`, `u`, `i`, `b`
- Code: `code`, `pre`
- Structure: `blockquote`, `h1`-`h6`, `ul`, `ol`, `li`
- Links and media: `a`, `img`
- Tables: `table`, `thead`, `tbody`, `tr`, `td`, `th`

## Accessibility

- **Keyboard Navigation**: Full keyboard support with focus trapping
- **Screen Readers**: Proper ARIA labels and semantic HTML
- **Focus Management**: Restores focus when modal closes
- **High Contrast**: Compatible with high contrast themes

### Keyboard Shortcuts

- `Escape`: Close modal
- `Tab`/`Shift+Tab`: Navigate between focusable elements
- `Enter`/`Space`: Activate buttons

## Customization

### Custom Action Buttons

```erb
<%= context_item_preview_modal(@context_item) do |component| %>
  <% component.with_primary_action do %>
    <button type="button" class="custom-primary-btn">
      Custom Action
    </button>
  <% end %>
  
  <% component.with_secondary_action do %>
    <button type="button" class="custom-secondary-btn">
      Another Action
    </button>
  <% end %>
  
  <% component.with_secondary_action do %>
    <button type="button" class="custom-tertiary-btn">
      Third Action
    </button>
  <% end %>
<% end %>
```

### Custom Styling

Override CSS classes in your application stylesheet:

```css
.context-item-preview-modal .code-content {
  background-color: #1a1a1a;
  color: #f8f8f2;
}

.context-item-preview-modal .markdown-content h1 {
  color: #2563eb;
  border-bottom: 2px solid #e5e7eb;
}
```

## Testing

The component includes comprehensive tests:

- Unit tests for content type detection
- Integration tests for rendering
- Security tests for sanitization
- Accessibility tests for keyboard navigation

Run tests:

```bash
rails test test/components/context_item_preview_component_test.rb
rails test test/system/context_item_preview_component_test.rb
```

## Dependencies

- **ViewComponent**: For component architecture
- **Stimulus**: For JavaScript interactions  
- **Tailwind CSS**: For styling
- **ActionText**: For content sanitization helpers

## Example Implementation

Here's a complete example of integrating the component into a document editor:

```erb
<!-- Document editor with context sidebar -->
<div class="flex h-screen">
  <!-- Main editor -->
  <div class="flex-1 p-6">
    <%= render EditorComponent.new(document: @document) %>
  </div>
  
  <!-- Context sidebar -->
  <div class="w-80 bg-gray-50 p-4">
    <h3 class="text-lg font-semibold mb-4">Context Items</h3>
    
    <% @document.context_items.recent.each do |context_item| %>
      <div class="mb-4">
        <%= context_item_card(context_item) %>
      </div>
    <% end %>
    
    <!-- Preview modals (hidden by default) -->
    <% @document.context_items.each do |context_item| %>
      <%= context_item_preview_modal(context_item) do |component| %>
        <% component.with_primary_action do %>
          <button type="button" 
                  class="btn-primary"
                  data-action="click->context-item-preview#insertContent">
            <svg class="w-4 h-4 mr-2"><!-- Insert icon --></svg>
            Insert into Document
          </button>
        <% end %>
        
        <% component.with_secondary_action do %>
          <button type="button" 
                  class="btn-secondary"
                  data-action="click->context-item-preview#copyContent">
            <svg class="w-4 h-4 mr-2"><!-- Copy icon --></svg>
            Copy to Clipboard
          </button>
        <% end %>
        
        <% component.with_secondary_action do %>
          <%= link_to edit_context_item_path(context_item), 
                      class: "btn-secondary" do %>
            <svg class="w-4 h-4 mr-2"><!-- Edit icon --></svg>
            Edit Item
          <% end %>
        <% end %>
      <% end %>
    <% end %>
  </div>
</div>

<script>
  // Handle insert events for Trix integration
  document.addEventListener('context-item-preview:insert', function(event) {
    const { content, contentType } = event.detail;
    
    if (contentType === 'code') {
      // Insert code with proper formatting
      insertCodeIntoTrix(content);
    } else {
      // Insert regular content
      insertTextIntoTrix(content);
    }
  });
  
  function insertCodeIntoTrix(content) {
    const trixEditor = document.querySelector('trix-editor');
    if (trixEditor && trixEditor.editor) {
      trixEditor.editor.insertHTML(`<pre><code>${content}</code></pre>`);
    }
  }
  
  function insertTextIntoTrix(content) {
    const trixEditor = document.querySelector('trix-editor');
    if (trixEditor && trixEditor.editor) {
      trixEditor.editor.insertString(content);
    }
  }
</script>
```

This component provides a robust, secure, and accessible way to preview and interact with context items in your Rails application.