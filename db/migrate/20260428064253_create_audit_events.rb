class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_events do |t|
      t.references :site,          null: false, foreign_key: true
      t.references :user,          null: false, foreign_key: true
      t.string     :action,        null: false
      t.string     :auditable_type
      t.bigint     :auditable_id

      t.datetime :created_at, null: false
    end

    add_index :audit_events, [ :site_id, :created_at ]
    add_index :audit_events, [ :auditable_type, :auditable_id ]
  end
end
