class PublishFailureAcknowledgmentsController < ApplicationController
  before_action :ensure_admin

  def create
    Audit::Event.where(site: Current.site)
                .unacknowledged_failures
                .update_all(acknowledged_at: Time.current)
    redirect_to root_path
  end

  private

  def ensure_admin
    redirect_to root_path unless Current.site && Current.user.admin_of?(Current.site)
  end
end
