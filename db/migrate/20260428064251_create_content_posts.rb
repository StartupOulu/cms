class CreateContentPosts < ActiveRecord::Migration[8.1]
  def change
    create_table :content_posts do |t|
      t.references :site, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string   :title,        null: false
      t.string   :slug,         null: false
      t.text     :body
      t.datetime :published_at

      t.timestamps
    end

    add_index :content_posts, [ :site_id, :slug ], unique: true
  end
end
