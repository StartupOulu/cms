class AddDraftSupportToContentPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :content_posts, :description, :text
    add_column :content_posts, :published_fields, :text
  end
end
