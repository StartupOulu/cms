class CreateSites < ActiveRecord::Migration[8.1]
  def change
    create_table :sites do |t|
      t.string :slug,                 null: false
      t.string :name,                 null: false
      t.string :repo_url,             null: false
      t.string :branch,               null: false, default: "main"
      t.string :site_url,             null: false
      t.string :publish_author_name,  null: false
      t.string :publish_author_email, null: false
      t.string :clone_path,           null: false
      t.string :deploy_key_path

      t.timestamps
    end

    add_index :sites, :slug, unique: true
  end
end
