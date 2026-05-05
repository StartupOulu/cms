class DashboardController < ApplicationController
  def index
    @recent_events = Audit::Event.where(site: Current.site)
                                 .includes(:user)
                                 .order(created_at: :desc)
                                 .limit(20)
    @failures = Audit::Event.where(site: Current.site)
                            .unacknowledged_failures
                            .includes(:user)
  end
end
