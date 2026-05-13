class Admin::ApplicationController < ApplicationController
  before_action :require_admin

  private

  def require_admin
    redirect_to root_path, alert: "Not authorised." unless Current.user.admin_of?(Current.site)
  end
end
