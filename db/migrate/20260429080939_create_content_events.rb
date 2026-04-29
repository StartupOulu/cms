class CreateContentEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :content_events do |t|
      t.references :site, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string   :title,       null: false
      t.string   :slug,        null: false
      t.datetime :start_at,    null: false
      t.datetime :end_at
      t.string   :location
      t.text     :summary
      t.text     :description
      t.string   :cta_title
      t.string   :cta_url
      t.datetime :published_at
      t.text     :published_fields
      t.timestamps
    end

    add_index :content_events, [ :site_id, :slug ], unique: true
  end
end
