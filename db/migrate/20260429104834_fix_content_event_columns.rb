class FixContentEventColumns < ActiveRecord::Migration[8.1]
  def change
    rename_column :content_events, :start_at, :start_time
    rename_column :content_events, :end_at,   :end_time
    rename_column :content_events, :cta_url,  :cta_link
    rename_column :content_events, :summary,  :excerpt
  end
end
