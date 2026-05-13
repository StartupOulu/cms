class DatabaseErrorSubscriber
  def report(error, handled:, severity:, context:, source: nil)
    sql = ActiveRecord::Base.sanitize_sql_array([
      "INSERT INTO error_logs (error_class, message, backtrace, context, handled, severity, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
      error.class.name,
      error.message,
      error.backtrace&.first(10)&.join("\n"),
      context.to_json,
      handled ? 1 : 0,
      severity.to_s,
      Time.current.utc.iso8601
    ])
    ActiveRecord::Base.connection.execute(sql)
  rescue StandardError => e
    Rails.logger.error("ErrorSubscriber failed to write: #{e.message}")
  end
end

Rails.error.subscribe(DatabaseErrorSubscriber.new)
