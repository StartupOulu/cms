class AddBlocksToContentPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :content_posts, :blocks, :text
    add_column :content_posts, :published_blocks, :text
    remove_column :content_posts, :body, :text
  end
end
