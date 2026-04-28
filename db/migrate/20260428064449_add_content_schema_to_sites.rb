class AddContentSchemaToSites < ActiveRecord::Migration[8.1]
  def change
    add_column :sites, :content_schema, :text
  end
end
