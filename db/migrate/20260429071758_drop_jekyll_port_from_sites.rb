class DropJekyllPortFromSites < ActiveRecord::Migration[8.1]
  def change
    remove_column :sites, :jekyll_port, :integer
  end
end
