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

ActiveRecord::Schema[8.1].define(version: 2026_04_28_064449) do
  create_table "audit_events", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "auditable_id"
    t.string "auditable_type"
    t.datetime "created_at", null: false
    t.integer "site_id", null: false
    t.integer "user_id", null: false
    t.index ["auditable_type", "auditable_id"], name: "index_audit_events_on_auditable_type_and_auditable_id"
    t.index ["site_id", "created_at"], name: "index_audit_events_on_site_id_and_created_at"
    t.index ["site_id"], name: "index_audit_events_on_site_id"
    t.index ["user_id"], name: "index_audit_events_on_user_id"
  end

  create_table "content_posts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "published_at"
    t.integer "site_id", null: false
    t.string "slug", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["site_id", "slug"], name: "index_content_posts_on_site_id_and_slug", unique: true
    t.index ["site_id"], name: "index_content_posts_on_site_id"
    t.index ["user_id"], name: "index_content_posts_on_user_id"
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
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "audit_events", "sites"
  add_foreign_key "audit_events", "users"
  add_foreign_key "content_posts", "sites"
  add_foreign_key "content_posts", "users"
  add_foreign_key "memberships", "sites"
  add_foreign_key "memberships", "users"
  add_foreign_key "sessions", "users"
end
