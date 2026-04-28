class GitStatusController < ApplicationController
  before_action :require_site
  before_action :require_admin

  def show
    @checks = Current.site.check_git
    @ok = @checks.all?(&:ok)
  end

  private

  def require_site
    redirect_to root_path, alert: "No site configured." unless Current.site
  end

  def require_admin
    redirect_to root_path, alert: "Not authorized." unless Current.user.admin_of?(Current.site)
  end
end
