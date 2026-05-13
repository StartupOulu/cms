class CreateErrorLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :error_logs do |t|
      t.string  :error_class, null: false
      t.text    :message,     null: false
      t.text    :backtrace
      t.text    :context
      t.boolean :handled,     null: false, default: false
      t.string  :severity,    null: false

      t.datetime :created_at, null: false
    end

    add_index :error_logs, :created_at
    add_index :error_logs, :handled
  end
end
