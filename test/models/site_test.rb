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
end
