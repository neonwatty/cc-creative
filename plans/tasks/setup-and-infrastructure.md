# Setup and Infrastructure Tasks

This document outlines the setup, authentication, deployment, and monitoring tasks for the Claude Code Creators Rails application.

## ✅ Task 1: Setup Rails 8 Project with Required Dependencies
**Status:** done  
**Priority:** high  
**Dependencies:** None

### Todo List:
- [x] Install Ruby 3.3+ if not already installed
- [x] Install Rails 8.0+: `gem install rails -v 8.0.0`
- [x] Create new Rails project: `rails new claude_code_creators --css=tailwind --database=sqlite3`
- [x] Add ruby_vite for JS bundling: Add `gem 'ruby_vite'` to Gemfile
- [x] Add required gems to Gemfile:
  - [x] `gem 'solid_cable'`
  - [x] `gem 'solid_queue'`
  - [x] `gem 'solid_cache'`
  - [x] `gem 'turbo-rails'`
  - [x] `gem 'stimulus-rails'`
  - [x] `gem 'view_component'`
  - [x] `gem 'active_storage'`
- [x] Run `bundle install`
- [x] Configure database.yml for PostgreSQL in production
- [x] Setup Vite configuration: `bin/rails vite:install`
- [x] Initialize Git repository: `git init`
- [x] Create initial commit with project structure

### Test Checklist:
- [x] Verify Rails server starts without errors
- [x] Confirm Tailwind CSS is properly configured by testing a simple Tailwind class
- [x] Verify Vite is working by creating a simple JS component
- [x] Test database connections for both development and production environments
- [x] Ensure all gems are properly installed and accessible

---

## ✅ Task 2: Implement Claude Code SDK Integration  
**Status:** done  
**Priority:** high  
**Dependencies:** Task 1

### Todo List:
- [x] Add Claude Code SDK gem to Gemfile: `gem 'claude_code_sdk'`
- [x] Create an initializer file at `config/initializers/claude_code_sdk.rb`
- [x] Configure SDK with API keys using Rails credentials
- [x] Create a service object for Claude Code interactions at `app/services/claude_service.rb`
- [x] Implement ClaudeService methods:
  - [x] `send_message(content, context = {})`
  - [x] `create_sub_agent(name, initial_context = {})`
- [x] Create a background job for async Claude interactions
- [x] Set up secure credential storage for API keys

### Test Checklist:
- [x] Write unit tests for ClaudeService methods
- [x] Create a mock for Claude Code SDK responses for testing
- [x] Test API key configuration is properly loaded from credentials
- [x] Verify sub-agent creation functionality
- [x] Test error handling for API failures

---

## ✅ Task 11: Implement User Authentication and Authorization
**Status:** done  
**Priority:** high  
**Dependencies:** Task 1

### Todo List:
- [x] **Subtask 11.1: Set up Devise authentication gem**
  - [x] Add Devise gem to Gemfile
  - [x] Run `bundle install`
  - [x] Execute `rails generate devise:install`
  - [x] Generate User model: `rails generate devise User`
  - [x] Run `rails db:migrate` to create users table
  
- [x] **Subtask 11.2: Customize User model with additional fields**
  - [x] Create migration to add name, role fields
  - [x] Update User model with validations
  - [x] Add enum for roles (user, admin, editor)
  - [x] Configure strong parameters in ApplicationController
  
- [x] **Subtask 11.3: Implement Pundit authorization system**
  - [x] Add Pundit gem to Gemfile
  - [x] Include Pundit in ApplicationController
  - [x] Generate application policy
  - [x] Create DocumentPolicy with permissions
  - [x] Implement role-based authorization logic
  
- [x] **Subtask 11.4: Create authentication UI**
  - [x] Run `rails generate devise:views`
  - [x] Style registration and login forms
  - [x] Create user profile page
  - [x] Implement password change functionality
  - [x] Add flash messages for authentication actions
  
- [x] **Subtask 11.5: Implement password reset and OAuth**
  - [x] Configure Action Mailer for password reset
  - [x] Enable Devise confirmable module
  - [x] Set up SMTP settings for production
  - [x] Add OmniAuth gems for Google and GitHub
  - [x] Configure OAuth providers in Devise initializer
  - [x] Create user association methods for OAuth accounts
  - [x] Handle OAuth callback and user creation/linking

### Test Checklist:
- [x] Test user registration and login flows
- [x] Verify authorization controls access correctly
- [x] Test password reset functionality
- [x] Verify email verification works
- [x] Test user profile management
- [x] Ensure OAuth login works correctly
- [x] Test role-based permissions

---

## ⏳ Task 14: Implement Deployment Configuration with Kamal
**Status:** pending  
**Priority:** low  
**Dependencies:** Task 1

### Todo List:
- [ ] Install Kamal: `gem install kamal`
- [ ] Initialize Kamal configuration: `kamal init`
- [ ] Configure deployment settings in `config/deploy.yml`:
  - [ ] Set service name and image registry
  - [ ] Configure server hosts
  - [ ] Set up Traefik labels for routing
  - [ ] Configure registry credentials
  - [ ] Set environment variables and secrets
- [ ] Create Dockerfile for the application:
  - [ ] Base image setup with Ruby 3.3-slim
  - [ ] Install system dependencies
  - [ ] Configure working directory
  - [ ] Install gems and npm packages
  - [ ] Copy application code
  - [ ] Precompile assets
  - [ ] Set startup command
- [ ] Configure database for production
- [ ] Set up SSL/TLS with Let's Encrypt
- [ ] Configure environment variables and secrets
- [ ] Set up CI/CD pipeline for automated deployment

### Test Checklist:
- [ ] Test Docker build process locally
- [ ] Verify application runs correctly in Docker container
- [ ] Test deployment to staging environment
- [ ] Verify SSL/TLS configuration works correctly
- [ ] Test environment variable configuration
- [ ] Ensure database migrations run correctly during deployment
- [ ] Test rollback functionality

---

## ⏳ Task 15: Implement Analytics and Monitoring
**Status:** pending  
**Priority:** low  
**Dependencies:** Tasks 1, 3

### Todo List:
- [ ] Implement application monitoring with Sentry:
  - [ ] Add Sentry gems to Gemfile
  - [ ] Configure Sentry initializer
  - [ ] Set up DSN and sampling rates
- [ ] Set up performance monitoring with Skylight:
  - [ ] Add Skylight gem to Gemfile
  - [ ] Configure skylight.yml
  - [ ] Set authentication credentials
- [ ] Implement user analytics with Ahoy:
  - [ ] Add ahoy_matey gem to Gemfile
  - [ ] Generate Ahoy models
  - [ ] Configure event tracking
  - [ ] Set up visit tracking
- [ ] Create custom event tracking for key user actions:
  - [ ] Document creation events
  - [ ] Editor usage events
  - [ ] Collaboration events
  - [ ] AI integration usage events
- [ ] Set up health check endpoints
- [ ] Implement logging enhancements
- [ ] Create admin dashboard for analytics
- [ ] Set up alerting for critical errors

### Test Checklist:
- [ ] Verify error tracking captures exceptions correctly
- [ ] Test performance monitoring data collection
- [ ] Verify user analytics events are tracked correctly
- [ ] Test health check endpoints
- [ ] Verify logging captures important information
- [ ] Test admin dashboard functionality
- [ ] Ensure alerting works for critical errors

---

## Summary

### Completed Tasks:
- ✅ Rails 8 project setup with all dependencies
- ✅ Claude Code SDK integration
- ✅ User authentication and authorization system

### Pending Tasks:
- ⏳ Deployment configuration with Kamal (low priority)
- ⏳ Analytics and monitoring implementation (low priority)

### Next Steps:
1. Complete deployment configuration when ready for production
2. Implement analytics and monitoring for production environment
3. Ensure all security best practices are followed
4. Document deployment procedures for team members