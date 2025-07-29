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

ActiveRecord::Schema[8.0].define(version: 2025_07_29_014639) do
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
    t.index ["context_type"], name: "index_claude_contexts_on_context_type"
    t.index ["session_id", "context_type"], name: "index_claude_contexts_on_session_id_and_context_type"
    t.index ["session_id"], name: "index_claude_contexts_on_session_id"
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

  create_table "context_items", force: :cascade do |t|
    t.integer "document_id", null: false
    t.integer "user_id", null: false
    t.text "content"
    t.string "item_type"
    t.string "title"
    t.json "metadata"
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_id"], name: "index_context_items_on_document_id"
    t.index ["user_id"], name: "index_context_items_on_user_id"
  end

  create_table "documents", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.text "tags"
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_documents_on_created_at"
    t.index ["user_id"], name: "index_documents_on_user_id"
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

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
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

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "context_items", "documents"
  add_foreign_key "context_items", "users"
  add_foreign_key "documents", "users"
  add_foreign_key "identities", "users"
  add_foreign_key "sessions", "users"
end
