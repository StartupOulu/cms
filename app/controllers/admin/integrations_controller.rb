class Admin::IntegrationsController < Admin::ApplicationController
  def show
    admin_sites = Current.user.memberships.where(role: "admin").includes(:site).map(&:site)
    @sites_status = admin_sites.map { |site| [ site, site.check_git ] }
    @all_ok = @sites_status.all? { |_site, checks| checks.all?(&:ok) }
  end
end
