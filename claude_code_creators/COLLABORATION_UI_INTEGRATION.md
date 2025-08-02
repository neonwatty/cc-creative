# Collaboration UI Components Integration Guide

This document provides guidance on integrating the Phase 2 collaboration UI components with the existing application.

## Components Overview

### 1. PresenceIndicatorsComponent
**Purpose**: Shows active collaborators with avatars and status
**Usage**: Display who is currently online and working on the document

```erb
<%= render PresenceIndicatorsComponent.new(
  users: @active_users,
  current_user: current_user,
  options: {
    show_names: true,
    show_cursors: false,
    max_display: 5,
    size: :medium
  }
) %>
```

### 2. TypingIndicatorsComponent
**Purpose**: Displays who is currently typing
**Usage**: Show real-time typing indicators at the bottom of the editor

```erb
<%= render TypingIndicatorsComponent.new(
  document: @document,
  current_user: current_user,
  options: {
    position: :bottom,
    style: :compact,
    max_visible: 3,
    show_avatars: true,
    animation_style: :pulse
  }
) %>
```

### 3. CursorTrackingComponent
**Purpose**: Visual real-time cursor positions
**Usage**: Overlay on the editor to show other users' cursors

```erb
<%= render CursorTrackingComponent.new(
  document: @document,
  current_user: current_user,
  options: {
    cursor_style: :default,
    show_labels: true,
    show_trails: false,
    smooth_movement: true,
    collision_detection: true,
    container_selector: '.editor-content'
  }
) %>
```

### 4. ConflictResolutionModalComponent
**Purpose**: Handle edit conflicts between users
**Usage**: Modal dialog for resolving conflicts

```erb
<%= render ConflictResolutionModalComponent.new(
  document: @document,
  current_user: current_user,
  options: {
    modal_size: :large,
    conflict_type: :content,
    auto_resolve: false,
    show_diff: true,
    enable_merge: true,
    resolution_timeout: 30000
  }
) %>
```

### 5. CollaborationStatusComponent
**Purpose**: Show connection status and collaboration state
**Usage**: Status indicator typically in top-right corner

```erb
<%= render CollaborationStatusComponent.new(
  document: @document,
  current_user: current_user,
  options: {
    position: :top_right,
    style: :compact,
    show_connection_quality: true,
    show_sync_status: true,
    show_last_save: true,
    auto_hide: false
  }
) %>
```

## Integration in Document Editor

### In your view template (e.g., `documents/show.html.erb`):

```erb
<div class="document-editor" data-controller="collaboration">
  <!-- Main document layout -->
  <div class="editor-header">
    <!-- Presence indicators in header -->
    <div class="presence-section">
      <%= render PresenceIndicatorsComponent.new(
        users: @active_users,
        current_user: current_user
      ) %>
    </div>
    
    <!-- Collaboration status in corner -->
    <%= render CollaborationStatusComponent.new(
      document: @document,
      current_user: current_user
    ) %>
  </div>

  <!-- Editor content area -->
  <div class="editor-content" data-controller="editor">
    <!-- Document content -->
    <%= render EditorComponent.new(document: @document) %>
    
    <!-- Cursor tracking overlay -->
    <%= render CursorTrackingComponent.new(
      document: @document,
      current_user: current_user,
      options: { container_selector: '.editor-content' }
    ) %>
  </div>

  <!-- Typing indicators at bottom -->
  <%= render TypingIndicatorsComponent.new(
    document: @document,
    current_user: current_user,
    options: { position: :bottom }
  ) %>

  <!-- Conflict resolution modal (hidden by default) -->
  <%= render ConflictResolutionModalComponent.new(
    document: @document,
    current_user: current_user
  ) %>
</div>
```

## Stimulus Controller Integration

### Main collaboration controller:

```javascript
// app/javascript/controllers/collaboration_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["presenceIndicators", "typingIndicators", "cursorTracking", "conflictModal", "statusIndicator"]
  static values = { documentId: Number, currentUserId: Number }

  connect() {
    this.setupCollaborationChannels()
    this.setupEventListeners()
  }

  setupCollaborationChannels() {
    // Initialize WebSocket connections
    this.presenceChannel = new PresenceChannel(this.documentIdValue)
    this.documentChannel = new DocumentEditChannel(this.documentIdValue)
  }

  setupEventListeners() {
    // Cross-component communication
    this.element.addEventListener("collaboration:user:joined", this.handleUserJoined.bind(this))
    this.element.addEventListener("collaboration:user:left", this.handleUserLeft.bind(this))
    this.element.addEventListener("collaboration:typing:started", this.handleTypingStarted.bind(this))
    this.element.addEventListener("collaboration:conflict:detected", this.handleConflictDetected.bind(this))
  }

  handleUserJoined(event) {
    // Notify all components
    this.dispatch("user:joined", { detail: event.detail })
  }

  handleConflictDetected(event) {
    // Show conflict resolution modal
    if (this.hasConflictModalTarget) {
      this.conflictModalTarget.style.display = "block"
    }
  }
}
```

## WebSocket Channel Integration

### Update your ActionCable channels to broadcast to the components:

```ruby
# app/channels/presence_channel.rb
class PresenceChannel < ApplicationCable::Channel
  def subscribed
    stream_from "presence_#{params[:document_id]}"
    # Broadcast user joined to presence indicators
    ActionCable.server.broadcast("presence_#{params[:document_id]}", {
      type: "user_joined",
      user: current_user.as_json,
      timestamp: Time.current
    })
  end

  def user_typing
    # Broadcast to typing indicators
    ActionCable.server.broadcast("presence_#{params[:document_id]}", {
      type: "user_typing",
      user_id: current_user.id,
      user_name: current_user.name,
      timestamp: Time.current
    })
  end

  def cursor_moved(data)
    # Broadcast to cursor tracking
    ActionCable.server.broadcast("presence_#{params[:document_id]}", {
      type: "cursor_moved",
      user_id: current_user.id,
      position: data["position"],
      timestamp: Time.current
    })
  end
end
```

## CSS Integration

Add the collaboration components stylesheet to your application:

```scss
// app/assets/stylesheets/application.css
@import "components/collaboration_components";
```

## Responsive Behavior

All components are designed to be responsive:

- **Mobile**: Components adapt to smaller screens
- **Tablet**: Optimized layouts for medium screens  
- **Desktop**: Full feature set with enhanced interactions

## Accessibility Features

- **ARIA attributes**: Proper labeling and live regions
- **Keyboard navigation**: Full keyboard support
- **Screen reader support**: Descriptive content and status updates
- **High contrast mode**: Enhanced visibility
- **Reduced motion**: Respects user preferences

## Performance Considerations

- **Throttled updates**: Prevents excessive DOM manipulation
- **Efficient animations**: Uses CSS transforms and GPU acceleration
- **Memory management**: Proper cleanup of timers and event listeners
- **Collision detection**: Optimized spatial calculations

## Configuration Options

Each component accepts extensive configuration options:

### Position Options
- `top_left`, `top_right`, `bottom_left`, `bottom_right`, `inline`

### Style Options  
- `minimal`, `compact`, `detailed`

### Animation Options
- `pulse`, `wave`, `dots`, `bounce`

### Size Options
- `small`, `medium`, `large`

## Event System

Components communicate through a standardized event system:

```javascript
// Dispatched events
this.dispatch("user:joined", { detail: { user } })
this.dispatch("typing:started", { detail: { userId, userName } })
this.dispatch("conflict:detected", { detail: { conflict } })
this.dispatch("cursor:moved", { detail: { userId, position } })
this.dispatch("status:changed", { detail: { status } })

// Listened events
this.element.addEventListener("collaboration:user:joined", handler)
this.element.addEventListener("collaboration:conflict:resolved", handler)
```

## Testing

Test components using the included test helpers:

```ruby
# test/components/collaboration_test.rb
class CollaborationComponentsTest < ViewComponent::TestCase
  def test_presence_indicators_renders
    render_inline(PresenceIndicatorsComponent.new(
      users: [users(:john), users(:jane)],
      current_user: users(:current)
    ))
    
    assert_selector ".presence-indicators"
    assert_selector "[data-controller='presence-indicator']"
  end
end
```

## Next Steps

1. **Test components individually** in isolation
2. **Integrate with existing editor** step by step
3. **Configure WebSocket channels** for real-time updates
4. **Customize styling** to match your design system
5. **Add error handling** for network issues
6. **Implement conflict resolution logic** for your use case

The components are designed to work independently and together, allowing for gradual integration and customization based on your specific requirements.