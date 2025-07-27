# ContextItems Controller Implementation

## Overview
This implementation provides a complete CRUD controller for ContextItems, which are nested under Documents in a Rails 8 application.

## Features Implemented

### 1. Full CRUD Actions
- **Index**: Lists all context items for a specific document
- **Show**: Displays a single context item
- **New/Create**: Creates new context items for a document
- **Edit/Update**: Updates existing context items
- **Destroy**: Deletes context items

### 2. Nested Routing
```ruby
resources :documents do
  resources :context_items
end
```

This creates routes like:
- `/documents/:document_id/context_items`
- `/documents/:document_id/context_items/:id`

### 3. Pundit Authorization
- Created `ContextItemPolicy` to handle authorization
- Users can only access context items belonging to their own documents
- Policy scope ensures users only see their own context items

### 4. Strong Parameters
```ruby
def context_item_params
  params.require(:context_item).permit(:content, :item_type, :title, :metadata)
end
```

### 5. Multiple Response Formats
- HTML responses for traditional web requests
- JSON responses for AJAX operations
- Turbo Stream responses for real-time updates

### 6. Security Features
- Authentication required for all actions
- Authorization checks on both document and context item levels
- Users cannot access, create, update, or delete other users' context items

### 7. Rails 8 Best Practices
- Uses `before_action` callbacks for common setup
- Implements proper RESTful routing
- Follows Rails conventions for naming and structure
- Includes comprehensive test coverage

## Files Created/Modified

### Controllers
- `/app/controllers/context_items_controller.rb` - Main controller implementation

### Policies
- `/app/policies/context_item_policy.rb` - Pundit authorization policy

### Views
- `/app/views/context_items/index.html.erb` - List view
- `/app/views/context_items/show.html.erb` - Detail view
- `/app/views/context_items/new.html.erb` - New form view
- `/app/views/context_items/edit.html.erb` - Edit form view
- `/app/views/context_items/_form.html.erb` - Shared form partial
- `/app/views/context_items/_context_item.html.erb` - Context item partial

### Routes
- `/config/routes.rb` - Added nested routes

### Tests
- `/test/controllers/context_items_controller_test.rb` - Controller tests
- `/test/policies/context_item_policy_test.rb` - Policy tests
- `/test/system/context_items_test.rb` - System tests
- `/spec/requests/context_items_spec.rb` - Request specs (RSpec)

### Models
- `/app/models/current.rb` - Updated to support user attribute

### Other
- Updated `/app/views/documents/show.html.erb` to include link to context items
- Updated fixtures for proper test data

## Usage Examples

### Creating a Context Item
```ruby
POST /documents/1/context_items
{
  context_item: {
    title: "API Response Example",
    content: "{ \"status\": \"success\" }",
    item_type: "snippet",
    metadata: "{\"language\": \"json\"}"
  }
}
```

### Updating a Context Item
```ruby
PATCH /documents/1/context_items/5
{
  context_item: {
    title: "Updated Title",
    content: "Updated content"
  }
}
```

### AJAX Operations
The controller supports AJAX requests with JSON responses:
```javascript
fetch('/documents/1/context_items', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json'
  },
  body: JSON.stringify({
    context_item: {
      title: "AJAX Item",
      content: "Created via AJAX",
      item_type: "draft"
    }
  })
})
```

## Testing

Run the tests with:
```bash
# Run controller tests
rails test test/controllers/context_items_controller_test.rb

# Run policy tests
rails test test/policies/context_item_policy_test.rb

# Run system tests
rails test test/system/context_items_test.rb

# Run all tests
rails test
```

## Security Considerations

1. **Authentication**: All actions require user authentication
2. **Authorization**: Users can only manage their own context items
3. **Cross-user Access**: Prevented at both controller and policy levels
4. **Input Validation**: Handled by model validations
5. **Strong Parameters**: Only permitted attributes can be mass-assigned

## Future Enhancements

Consider adding:
1. Pagination for large numbers of context items
2. Search/filtering capabilities
3. Bulk operations (delete multiple, export)
4. Version history for context items
5. Real-time collaboration features
6. API endpoints for external integrations