class Admin::ErrorLogsController < Admin::ApplicationController
  def index
    @error_logs = ActiveRecord::Base.connection.execute(
      "SELECT * FROM error_logs ORDER BY created_at DESC LIMIT 30"
    ).to_a
  end
end
