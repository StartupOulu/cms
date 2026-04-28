class ApplicationController < ActionController::Base
  include Authentication

  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :set_current_site

  private

  def set_current_site
    return unless Current.user
    Current.site = Current.user.sites.first
  end
end
