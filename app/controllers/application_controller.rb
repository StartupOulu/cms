class ApplicationController < ActionController::Base
  include Authentication

  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :set_current_site
  before_action :require_password_change
  around_action :set_error_context

  private

  def set_error_context
    Rails.error.set_context(
      user_id: Current.user&.id,
      site_id: Current.site&.id,
      url: request.url,
      method: request.method
    )
    yield
  end

  def set_current_site
    return unless Current.user
    Current.site = Current.user.sites.first
  end

  def require_password_change
    return unless Current.user&.must_change_password?
    redirect_to edit_password_change_path
  end
end
