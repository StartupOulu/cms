class AddTitleAndFailureFieldsToAuditEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :audit_events, :title,           :string
    add_column :audit_events, :error_message,   :text
    add_column :audit_events, :acknowledged_at, :datetime
  end
end
