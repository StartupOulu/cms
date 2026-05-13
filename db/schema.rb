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

ActiveRecord::Schema[8.1].define(version: 2026_05_12_000001) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "audit_events", force: :cascade do |t|
    t.datetime "acknowledged_at"
    t.string "action", null: false
    t.bigint "auditable_id"
    t.string "auditable_type"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.integer "site_id", null: false
    t.string "title"
    t.integer "user_id", null: false
    t.index ["auditable_type", "auditable_id"], name: "index_audit_events_on_auditable_type_and_auditable_id"
    t.index ["site_id", "created_at"], name: "index_audit_events_on_site_id_and_created_at"
    t.index ["site_id"], name: "index_audit_events_on_site_id"
    t.index ["user_id"], name: "index_audit_events_on_user_id"
  end

  create_table "content_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "cta_link"
    t.string "cta_title"
    t.text "description"
    t.datetime "end_time"
    t.text "excerpt"
    t.string "location"
    t.datetime "published_at"
    t.text "published_fields"
    t.integer "site_id", null: false
    t.string "slug", null: false
    t.datetime "start_time", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["site_id", "slug"], name: "index_content_events_on_site_id_and_slug", unique: true
    t.index ["site_id"], name: "index_content_events_on_site_id"
    t.index ["user_id"], name: "index_content_events_on_user_id"
  end

  create_table "content_posts", force: :cascade do |t|
    t.text "blocks"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "published_at"
    t.text "published_blocks"
    t.text "published_fields"
    t.integer "site_id", null: false
    t.string "slug", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["site_id", "slug"], name: "index_content_posts_on_site_id_and_slug", unique: true
    t.index ["site_id"], name: "index_content_posts_on_site_id"
    t.index ["user_id"], name: "index_content_posts_on_user_id"
  end

  create_table "error_logs", force: :cascade do |t|
    t.text "backtrace"
    t.text "context"
    t.datetime "created_at", null: false
    t.string "error_class", null: false
    t.boolean "handled", default: false, null: false
    t.text "message", null: false
    t.string "severity", null: false
    t.index ["created_at"], name: "index_error_logs_on_created_at"
    t.index ["handled"], name: "index_error_logs_on_handled"
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "role", null: false
    t.integer "site_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["site_id"], name: "index_memberships_on_site_id"
    t.index ["user_id", "site_id"], name: "index_memberships_on_user_id_and_site_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "sites", force: :cascade do |t|
    t.string "branch", default: "main", null: false
    t.string "clone_path", null: false
    t.text "content_schema"
    t.datetime "created_at", null: false
    t.string "deploy_key_path"
    t.string "name", null: false
    t.string "publish_author_email", null: false
    t.string "publish_author_name", null: false
    t.string "repo_url", null: false
    t.string "site_url", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_sites_on_slug", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "display_name"
    t.string "email_address", null: false
    t.boolean "must_change_password", default: false, null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "audit_events", "sites"
  add_foreign_key "audit_events", "users"
  add_foreign_key "content_events", "sites"
  add_foreign_key "content_events", "users"
  add_foreign_key "content_posts", "sites"
  add_foreign_key "content_posts", "users"
  add_foreign_key "memberships", "sites"
  add_foreign_key "memberships", "users"
  add_foreign_key "sessions", "users"
end
