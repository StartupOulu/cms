class Admin::IntegrationsController < Admin::ApplicationController
  def show
    admin_sites = Current.user.memberships.where(role: "admin").includes(:site).map(&:site)
    @sites_status = admin_sites.map { |site| [ site, site.check_git ] }
    @all_ok = @sites_status.all? { |_site, checks| checks.all?(&:ok) }
    @disk_stats = disk_stats
  end

  private

  def disk_stats
    out, _err, status = Open3.capture3("df", "-Pk", Rails.root.to_s)
    return nil unless status.success?

    line = out.lines[1]
    return nil unless line

    parts = line.split
    total_kb = parts[1].to_i
    used_kb  = parts[2].to_i
    avail_kb = parts[3].to_i
    return nil if total_kb.zero?

    pct = parts[4].to_i
    severity = if pct >= 90 then "critical"
               elsif pct >= 75 then "warn"
               else "ok"
               end

    { total: total_kb * 1024, used: used_kb * 1024, available: avail_kb * 1024, percent: pct, severity: severity }
  end
end
