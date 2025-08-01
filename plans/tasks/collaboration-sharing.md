# Collaboration and Sharing Tasks

This document outlines the file integration, real-time collaboration, and sharing features for the Claude Code Creators Rails application.

## ✅ Task 6: Implement File Integration with Cloud Services
**Status:** done  
**Priority:** medium  
**Dependencies:** Tasks 1, 3

### Todo List:
- [x] Set up ActiveStorage for file handling:
  - [x] Run `rails active_storage:install`
  - [x] Run migrations for ActiveStorage tables
  - [x] Configure storage service for development
  - [x] Configure storage service for production

- [x] Add cloud service integration gems:
  - [x] Add `gem 'google_drive'` to Gemfile
  - [x] Add `gem 'dropbox_api'` to Gemfile
  - [x] Add `gem 'notion-ruby-client'` to Gemfile
  - [x] Run `bundle install`

- [x] Create GoogleDriveService:
  - [x] Create service class structure
  - [x] Implement authentication setup
  - [x] Create list_files method
  - [x] Implement import_file method
  - [x] Create export_document method
  - [x] Add error handling
  - [x] Implement folder navigation

- [x] Create DropboxService:
  - [x] Create service class structure
  - [x] Implement OAuth authentication
  - [x] Create file listing functionality
  - [x] Implement file import
  - [x] Create document export
  - [x] Add folder support
  - [x] Handle API rate limits

- [x] Create NotionService:
  - [x] Create service class structure
  - [x] Implement API authentication
  - [x] Create page listing
  - [x] Implement page import
  - [x] Create document export to Notion
  - [x] Handle Notion blocks
  - [x] Map Notion content types

- [x] Implement OAuth flow:
  - [x] Create OAuth controller
  - [x] Implement Google OAuth
  - [x] Implement Dropbox OAuth
  - [x] Implement Notion OAuth
  - [x] Store OAuth tokens securely
  - [x] Handle token refresh
  - [x] Create disconnect functionality

- [x] Create UI for connecting accounts:
  - [x] Design integrations settings page
  - [x] Add connect/disconnect buttons
  - [x] Show connection status
  - [x] Display connected account info
  - [x] Add service icons
  - [x] Create success/error messages

- [x] Implement file browser UI:
  - [x] Create modal file browser component
  - [x] Display folder hierarchy
  - [x] Show file listings
  - [x] Add file type icons
  - [x] Implement pagination
  - [x] Add search functionality
  - [x] Create breadcrumb navigation

- [x] Add import/export functionality:
  - [x] Create import progress UI
  - [x] Handle large file imports
  - [x] Convert file formats
  - [x] Create export options UI
  - [x] Support multiple export formats
  - [x] Add export queuing

- [x] Create background jobs:
  - [x] Create ImportFileJob
  - [x] Create ExportDocumentJob
  - [x] Add job status tracking
  - [x] Implement retry logic
  - [x] Send completion notifications

### Test Checklist:
- [x] Test OAuth authentication flow for each service
- [x] Verify file listing functionality
- [x] Test file import from each service
- [x] Verify document export to each service
- [x] Test error handling for API failures
- [x] Ensure file operations work asynchronously

---

## ⏳ Task 10: Implement Real-Time Collaboration Support
**Status:** pending  
**Priority:** medium  
**Dependencies:** Tasks 3, 9

### Todo List:
- [ ] Set up SolidCable for WebSocket communication:
  - [ ] Configure SolidCable adapter
  - [ ] Set adapter to PostgreSQL
  - [ ] Configure worker pool size
  - [ ] Set up connection monitoring
  - [ ] Configure heartbeat settings

- [ ] Implement Yjs for collaborative editing:
  - [ ] Install Yjs: `yarn add yjs`
  - [ ] Install y-websocket provider
  - [ ] Create Yjs document structure
  - [ ] Set up WebSocket provider
  - [ ] Bind Yjs to Trix editor
  - [ ] Handle connection states
  - [ ] Implement offline support

- [ ] Create DocumentChannel:
  - [ ] Generate channel with Rails
  - [ ] Implement subscribed method
  - [ ] Create stream_for document
  - [ ] Handle cursor_moved action
  - [ ] Implement content_changed action
  - [ ] Add user_joined action
  - [ ] Add user_left action
  - [ ] Implement selection_changed

- [ ] Create collaborative editor controller:
  - [ ] Initialize Yjs document
  - [ ] Set up WebSocket provider
  - [ ] Bind to editor
  - [ ] Handle connection events
  - [ ] Manage document sync
  - [ ] Implement conflict resolution

- [ ] Implement presence tracking:
  - [ ] Track active users
  - [ ] Store cursor positions
  - [ ] Track user selections
  - [ ] Monitor user activity
  - [ ] Handle idle states
  - [ ] Clean up disconnected users

- [ ] Create UI for active collaborators:
  - [ ] Design collaborator list
  - [ ] Show user avatars
  - [ ] Display user names
  - [ ] Add online indicators
  - [ ] Show user colors
  - [ ] Create collaborator menu

- [ ] Implement live cursor tracking:
  - [ ] Capture cursor movements
  - [ ] Broadcast cursor positions
  - [ ] Render remote cursors
  - [ ] Add cursor labels
  - [ ] Use user colors
  - [ ] Smooth cursor animations

- [ ] Add voice chat using WebRTC:
  - [ ] Set up WebRTC connection
  - [ ] Implement signaling server
  - [ ] Create audio controls UI
  - [ ] Add mute/unmute functionality
  - [ ] Handle connection quality
  - [ ] Implement echo cancellation

- [ ] Create shared room functionality:
  - [ ] Generate room codes
  - [ ] Create room joining UI
  - [ ] Implement room permissions
  - [ ] Add room settings
  - [ ] Create room invitation system
  - [ ] Handle room lifecycle

- [ ] Implement permissions system:
  - [ ] Define permission levels
  - [ ] Create owner permissions
  - [ ] Add editor permissions
  - [ ] Implement viewer permissions
  - [ ] Create permission UI
  - [ ] Handle permission changes

### Test Checklist:
- [ ] Test real-time document updates between multiple clients
- [ ] Verify cursor positions update correctly
- [ ] Test presence indicators for joining/leaving users
- [ ] Verify conflict resolution works correctly
- [ ] Test voice chat functionality
- [ ] Ensure collaboration features work across different browsers
- [ ] Test permission controls for document access

---

## ⏳ Task 13: Implement Export and Sharing Features
**Status:** pending  
**Priority:** medium  
**Dependencies:** Tasks 3, 11

### Todo List:
- [ ] Create DocumentExportService:
  - [ ] Create service class structure
  - [ ] Implement to_pdf method using PDF library
  - [ ] Create to_markdown converter
  - [ ] Implement to_html exporter
  - [ ] Create to_docx using docx library
  - [ ] Add formatting preservation
  - [ ] Handle embedded media

- [ ] Implement PDF export:
  - [ ] Add PDF generation gem (Prawn or similar)
  - [ ] Create PDF templates
  - [ ] Preserve formatting
  - [ ] Handle images and media
  - [ ] Add page numbering
  - [ ] Create cover page option

- [ ] Implement Markdown export:
  - [ ] Convert rich text to Markdown
  - [ ] Preserve formatting where possible
  - [ ] Handle special characters
  - [ ] Export metadata as frontmatter
  - [ ] Create GitHub-flavored option

- [ ] Implement DOCX export:
  - [ ] Add DOCX generation gem
  - [ ] Map styles to Word styles
  - [ ] Preserve formatting
  - [ ] Handle images
  - [ ] Create document properties

- [ ] Create ShareLink model:
  - [ ] Generate model with token field
  - [ ] Add expiration date field
  - [ ] Add access_count tracking
  - [ ] Implement secure token generation
  - [ ] Add password protection option
  - [ ] Create custom URL slugs

- [ ] Implement share link controller:
  - [ ] Create shareable link endpoint
  - [ ] Implement link access endpoint
  - [ ] Add link management actions
  - [ ] Create link statistics endpoint
  - [ ] Handle link expiration
  - [ ] Implement link revocation

- [ ] Add email invitation functionality:
  - [ ] Create invitation mailer
  - [ ] Design invitation email template
  - [ ] Add invitation tracking
  - [ ] Implement acceptance flow
  - [ ] Send reminder emails
  - [ ] Track invitation status

- [ ] Create export UI:
  - [ ] Design export modal
  - [ ] Add format selection
  - [ ] Show export options
  - [ ] Display progress indicator
  - [ ] Add download button
  - [ ] Create export history

- [ ] Implement permission settings:
  - [ ] Create permissions UI
  - [ ] Add view-only option
  - [ ] Implement edit permissions
  - [ ] Add comment permissions
  - [ ] Create download restrictions
  - [ ] Set expiration options

- [ ] Add public/private visibility:
  - [ ] Create visibility toggle
  - [ ] Implement public document view
  - [ ] Add SEO considerations
  - [ ] Create unlisted option
  - [ ] Handle search indexing
  - [ ] Add social sharing

### Test Checklist:
- [ ] Test document export in each format
- [ ] Verify share link generation and access
- [ ] Test email invitation functionality
- [ ] Verify permission settings work correctly
- [ ] Test expiration of share links
- [ ] Ensure public/private visibility controls work
- [ ] Test accessing shared documents as different users

---

## Summary

### Completed Tasks:
- ✅ File integration with Google Drive, Dropbox, and Notion
- ✅ OAuth authentication for cloud services
- ✅ Import/export functionality with background jobs
- ✅ File browser UI for cloud services

### Pending Tasks:
- ⏳ Real-time collaboration with live cursors and presence
- ⏳ Export functionality in multiple formats
- ⏳ Sharing features with permissions and links

### Key Features to Implement:
1. **Real-time Collaboration** - Live editing with multiple users
2. **Presence Indicators** - See who's working on documents
3. **Export Options** - PDF, Markdown, HTML, DOCX formats
4. **Sharing System** - Links, invitations, and permissions
5. **Voice Chat** - Optional WebRTC communication

### Integration Considerations:
- Ensure WebSocket connections are stable
- Handle offline editing scenarios
- Optimize for performance with multiple users
- Consider security for shared documents
- Plan for scalability of collaboration features