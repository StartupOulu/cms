class AddJekyllPortToSites < ActiveRecord::Migration[8.1]
  def change
    add_column :sites, :jekyll_port, :integer
  end
end
