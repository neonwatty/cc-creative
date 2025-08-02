# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_08_02_205920) do
  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "claude_contexts", force: :cascade do |t|
    t.string "session_id"
    t.string "context_type"
    t.json "content"
    t.integer "token_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "document_id"
    t.integer "user_id"
    t.text "context_data"
    t.index ["context_type"], name: "index_claude_contexts_on_context_type"
    t.index ["document_id", "user_id"], name: "index_claude_contexts_on_document_id_and_user_id"
    t.index ["document_id"], name: "index_claude_contexts_on_document_id"
    t.index ["session_id", "context_type"], name: "index_claude_contexts_on_session_id_and_context_type"
    t.index ["session_id"], name: "index_claude_contexts_on_session_id"
    t.index ["user_id", "created_at"], name: "index_claude_contexts_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_claude_contexts_on_user_id"
  end

  create_table "claude_messages", force: :cascade do |t|
    t.string "session_id"
    t.string "sub_agent_name"
    t.string "role"
    t.text "content"
    t.json "context"
    t.json "message_metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id", "created_at"], name: "index_claude_messages_on_session_id_and_created_at"
    t.index ["session_id"], name: "index_claude_messages_on_session_id"
    t.index ["sub_agent_name"], name: "index_claude_messages_on_sub_agent_name"
  end

  create_table "claude_sessions", force: :cascade do |t|
    t.string "session_id"
    t.json "context"
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_claude_sessions_on_session_id", unique: true
  end

  create_table "cloud_files", force: :cascade do |t|
    t.integer "cloud_integration_id", null: false
    t.string "provider"
    t.string "file_id"
    t.string "name"
    t.string "mime_type"
    t.integer "size"
    t.text "metadata"
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "document_id"
    t.index ["cloud_integration_id"], name: "index_cloud_files_on_cloud_integration_id"
    t.index ["document_id"], name: "index_cloud_files_on_document_id"
  end

  create_table "cloud_integrations", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "provider"
    t.text "access_token"
    t.text "refresh_token"
    t.datetime "expires_at"
    t.text "settings"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_cloud_integrations_on_user_id"
  end

  create_table "collaboration_sessions", force: :cascade do |t|
    t.integer "document_id", null: false
    t.integer "user_id", null: false
    t.string "session_id", null: false
    t.string "status", default: "active", null: false
    t.text "settings"
    t.integer "max_users", default: 10
    t.integer "active_users_count", default: 0
    t.datetime "started_at", null: false
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_id", "status"], name: "index_collaboration_sessions_on_document_id_and_status"
    t.index ["document_id"], name: "index_collaboration_sessions_on_document_id"
    t.index ["session_id"], name: "index_collaboration_sessions_on_session_id", unique: true
    t.index ["started_at"], name: "index_collaboration_sessions_on_started_at"
    t.index ["user_id"], name: "index_collaboration_sessions_on_user_id"
  end

  create_table "command_audit_logs", force: :cascade do |t|
    t.string "command", null: false
    t.text "parameters"
    t.integer "user_id", null: false
    t.integer "document_id", null: false
    t.datetime "executed_at", null: false
    t.decimal "execution_time", precision: 8, scale: 4
    t.string "status", null: false
    t.text "error_message"
    t.string "ip_address"
    t.text "user_agent"
    t.string "session_id"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["command", "status"], name: "index_command_audit_logs_on_command_and_status"
    t.index ["document_id", "executed_at"], name: "index_command_audit_logs_on_document_id_and_executed_at"
    t.index ["document_id"], name: "index_command_audit_logs_on_document_id"
    t.index ["session_id"], name: "index_command_audit_logs_on_session_id"
    t.index ["user_id", "executed_at"], name: "index_command_audit_logs_on_user_id_and_executed_at"
    t.index ["user_id"], name: "index_command_audit_logs_on_user_id"
  end

  create_table "command_histories", force: :cascade do |t|
    t.string "command", null: false
    t.text "parameters"
    t.integer "user_id", null: false
    t.integer "document_id", null: false
    t.datetime "executed_at", null: false
    t.decimal "execution_time", precision: 8, scale: 4
    t.string "status", null: false
    t.text "result_data"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["command", "status"], name: "index_command_histories_on_command_and_status"
    t.index ["document_id", "executed_at"], name: "index_command_histories_on_document_id_and_executed_at"
    t.index ["document_id"], name: "index_command_histories_on_document_id"
    t.index ["user_id", "executed_at"], name: "index_command_histories_on_user_id_and_executed_at"
    t.index ["user_id"], name: "index_command_histories_on_user_id"
  end

  create_table "context_items", force: :cascade do |t|
    t.integer "document_id", null: false
    t.integer "user_id", null: false
    t.text "content"
    t.string "item_type"
    t.string "title"
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "position"
    t.text "search_content"
    t.index ["created_at"], name: "index_context_items_on_created_at"
    t.index ["document_id", "item_type", "position"], name: "index_context_items_on_document_id_and_item_type_and_position"
    t.index ["document_id", "user_id"], name: "index_context_items_on_document_id_and_user_id"
    t.index ["document_id"], name: "index_context_items_on_document_id"
    t.index ["item_type"], name: "index_context_items_on_item_type"
    t.index ["search_content"], name: "index_context_items_on_search_content"
    t.index ["user_id"], name: "index_context_items_on_user_id"
  end

  create_table "context_permissions", force: :cascade do |t|
    t.integer "context_item_id", null: false
    t.integer "user_id", null: false
    t.integer "granted_by_id", null: false
    t.text "permissions", null: false
    t.datetime "granted_at", null: false
    t.datetime "expires_at"
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["context_item_id", "user_id"], name: "index_context_permissions_on_context_item_id_and_user_id", unique: true
    t.index ["context_item_id"], name: "index_context_permissions_on_context_item_id"
    t.index ["expires_at"], name: "index_context_permissions_on_expires_at"
    t.index ["granted_by_id"], name: "index_context_permissions_on_granted_by_id"
    t.index ["user_id", "status"], name: "index_context_permissions_on_user_id_and_status"
    t.index ["user_id"], name: "index_context_permissions_on_user_id"
  end

  create_table "document_versions", force: :cascade do |t|
    t.integer "document_id", null: false
    t.integer "version_number", null: false
    t.string "title", null: false
    t.text "content_snapshot", null: false
    t.text "description_snapshot"
    t.json "tags_snapshot", default: []
    t.string "version_name"
    t.text "version_notes"
    t.integer "created_by_user_id", null: false
    t.boolean "is_auto_version", default: false, null: false
    t.integer "word_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_user_id"], name: "index_document_versions_on_created_by_user_id"
    t.index ["document_id", "created_at"], name: "index_document_versions_on_document_id_and_created_at"
    t.index ["document_id", "version_number"], name: "index_document_versions_on_document_id_and_version_number", unique: true
    t.index ["document_id"], name: "index_document_versions_on_document_id"
    t.index ["is_auto_version"], name: "index_document_versions_on_is_auto_version"
  end

  create_table "documents", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.text "tags"
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "current_version_number", default: 0
    t.index ["created_at"], name: "index_documents_on_created_at"
    t.index ["current_version_number"], name: "index_documents_on_current_version_number"
    t.index ["user_id"], name: "index_documents_on_user_id"
  end

  create_table "extension_logs", force: :cascade do |t|
    t.integer "plugin_id", null: false
    t.integer "user_id", null: false
    t.string "action"
    t.string "status"
    t.text "error_message"
    t.integer "execution_time"
    t.json "resource_usage"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["plugin_id"], name: "index_extension_logs_on_plugin_id"
    t.index ["user_id"], name: "index_extension_logs_on_user_id"
  end

  create_table "identities", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "provider", null: false
    t.string "uid", null: false
    t.string "email"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "uid"], name: "index_identities_on_provider_and_uid", unique: true
    t.index ["user_id"], name: "index_identities_on_user_id"
  end

  create_table "operational_transforms", force: :cascade do |t|
    t.integer "document_id", null: false
    t.integer "user_id", null: false
    t.string "operation_type", null: false
    t.integer "position", null: false
    t.integer "length"
    t.text "content"
    t.decimal "timestamp", precision: 15, scale: 6, null: false
    t.datetime "applied_at"
    t.string "status", default: "pending", null: false
    t.boolean "conflict_resolved", default: false
    t.text "conflict_resolution_data"
    t.string "operation_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_id", "status"], name: "index_operational_transforms_on_document_id_and_status"
    t.index ["document_id", "timestamp"], name: "index_operational_transforms_on_document_id_and_timestamp"
    t.index ["document_id"], name: "index_operational_transforms_on_document_id"
    t.index ["operation_id"], name: "index_operational_transforms_on_operation_id", unique: true
    t.index ["user_id", "timestamp"], name: "index_operational_transforms_on_user_id_and_timestamp"
    t.index ["user_id"], name: "index_operational_transforms_on_user_id"
  end

  create_table "plugin_installations", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "plugin_id", null: false
    t.json "configuration"
    t.string "status"
    t.datetime "installed_at"
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["plugin_id"], name: "index_plugin_installations_on_plugin_id"
    t.index ["user_id"], name: "index_plugin_installations_on_user_id"
  end

  create_table "plugin_permissions", force: :cascade do |t|
    t.integer "plugin_id", null: false
    t.integer "user_id", null: false
    t.string "permission_type"
    t.string "resource"
    t.datetime "granted_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["plugin_id"], name: "index_plugin_permissions_on_plugin_id"
    t.index ["user_id"], name: "index_plugin_permissions_on_user_id"
  end

  create_table "plugins", force: :cascade do |t|
    t.string "name"
    t.string "version"
    t.text "description"
    t.string "author"
    t.string "category"
    t.string "status"
    t.json "metadata"
    t.json "permissions"
    t.json "sandbox_config"
    t.datetime "installed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "sub_agent_messages", force: :cascade do |t|
    t.integer "sub_agent_id", null: false
    t.integer "user_id", null: false
    t.string "role"
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sub_agent_id"], name: "index_sub_agent_messages_on_sub_agent_id"
    t.index ["user_id"], name: "index_sub_agent_messages_on_user_id"
  end

  create_table "sub_agents", force: :cascade do |t|
    t.integer "document_id", null: false
    t.integer "user_id", null: false
    t.string "name", null: false
    t.string "agent_type", null: false
    t.string "status", default: "active"
    t.string "external_id"
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "context", default: {}
    t.text "system_prompt"
    t.index ["agent_type"], name: "index_sub_agents_on_agent_type"
    t.index ["created_at"], name: "index_sub_agents_on_created_at"
    t.index ["document_id", "agent_type"], name: "index_sub_agents_on_document_id_and_agent_type"
    t.index ["document_id", "user_id"], name: "index_sub_agents_on_document_id_and_user_id"
    t.index ["document_id"], name: "index_sub_agents_on_document_id"
    t.index ["external_id"], name: "index_sub_agents_on_external_id"
    t.index ["status"], name: "index_sub_agents_on_status"
    t.index ["user_id"], name: "index_sub_agents_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "role", default: "user"
    t.boolean "email_confirmed", default: false, null: false
    t.datetime "email_confirmed_at"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "workflow_tasks", force: :cascade do |t|
    t.integer "document_id", null: false
    t.integer "assigned_to_id", null: false
    t.integer "created_by_id", null: false
    t.string "title", null: false
    t.text "description"
    t.string "priority", default: "medium", null: false
    t.string "status", default: "pending", null: false
    t.string "category"
    t.decimal "estimated_hours", precision: 8, scale: 2
    t.decimal "time_spent", precision: 8, scale: 2, default: "0.0"
    t.integer "progress_percentage", default: 0
    t.datetime "due_date"
    t.datetime "completed_at"
    t.text "acceptance_criteria"
    t.text "tags"
    t.string "git_branch"
    t.text "dependencies"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assigned_to_id", "status"], name: "index_workflow_tasks_on_assigned_to_id_and_status"
    t.index ["assigned_to_id"], name: "index_workflow_tasks_on_assigned_to_id"
    t.index ["created_by_id", "created_at"], name: "index_workflow_tasks_on_created_by_id_and_created_at"
    t.index ["created_by_id"], name: "index_workflow_tasks_on_created_by_id"
    t.index ["document_id", "status"], name: "index_workflow_tasks_on_document_id_and_status"
    t.index ["document_id"], name: "index_workflow_tasks_on_document_id"
    t.index ["due_date"], name: "index_workflow_tasks_on_due_date"
    t.index ["priority"], name: "index_workflow_tasks_on_priority"
  end

  add_foreign_key "claude_contexts", "documents"
  add_foreign_key "claude_contexts", "users"
  add_foreign_key "collaboration_sessions", "documents"
  add_foreign_key "collaboration_sessions", "users"
  add_foreign_key "command_audit_logs", "documents"
  add_foreign_key "command_audit_logs", "users"
  add_foreign_key "command_histories", "documents"
  add_foreign_key "command_histories", "users"
  add_foreign_key "context_permissions", "context_items"
  add_foreign_key "context_permissions", "users"
  add_foreign_key "context_permissions", "users", column: "granted_by_id"
  add_foreign_key "documents", "users"
  add_foreign_key "extension_logs", "plugins"
  add_foreign_key "extension_logs", "users"
  add_foreign_key "identities", "users"
  add_foreign_key "operational_transforms", "documents"
  add_foreign_key "operational_transforms", "users"
  add_foreign_key "plugin_installations", "plugins"
  add_foreign_key "plugin_installations", "users"
  add_foreign_key "plugin_permissions", "plugins"
  add_foreign_key "plugin_permissions", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "sub_agent_messages", "sub_agents"
  add_foreign_key "sub_agent_messages", "users"
  add_foreign_key "sub_agents", "documents"
  add_foreign_key "sub_agents", "users"
  add_foreign_key "workflow_tasks", "documents"
  add_foreign_key "workflow_tasks", "users", column: "assigned_to_id"
  add_foreign_key "workflow_tasks", "users", column: "created_by_id"
end
