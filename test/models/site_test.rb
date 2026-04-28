require "test_helper"

class SiteTest < ActiveSupport::TestCase
  def site
    sites(:startupoulu)
  end

  test "valid fixture" do
    assert site.valid?
  end

  test "slug must be unique" do
    duplicate = Site.new(site.attributes.except("id", "created_at", "updated_at"))
    assert_not duplicate.valid?
    assert duplicate.errors[:slug].any?
  end

  test "slug only allows lowercase letters, numbers, and hyphens" do
    site.slug = "Has Spaces"
    assert_not site.valid?
  end

  test "publish_author combines name and email" do
    assert_equal "CMS Bot <cms@startupoulu.com>", site.publish_author
  end

  test "membership_for returns membership for a user" do
    assert_equal memberships(:admin_on_startupoulu), site.membership_for(users(:admin))
  end

  test "membership_for returns nil for non-member" do
    stranger = User.create!(email_address: "stranger@example.com", password: "secret123")
    assert_nil site.membership_for(stranger)
  end

  # check_git

  test "check_git reports missing clone" do
    site.clone_path = "/nonexistent/path"
    checks = site.check_git
    assert_equal 1, checks.length
    assert_not checks.first.ok
    assert_match "No git repository found", checks.first.error
  end

  test "check_git reports remote URL mismatch" do
    with_git_site(site) do
      site.repo_url = "git@github.com:wrong/repo.git"
      checks = site.check_git
      failed = checks.find { |c| !c.ok }
      assert_equal "Remote URL", failed.label
      assert_match "git@github.com:wrong/repo.git", failed.error
    end
  end

  test "check_git passes all checks with a valid clone" do
    with_git_site(site) do
      checks = site.check_git
      assert checks.all?(&:ok), checks.map(&:error).compact.join(", ")
      assert_equal 3, checks.length
    end
  end
end
