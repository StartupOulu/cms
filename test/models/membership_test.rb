require "test_helper"

class MembershipTest < ActiveSupport::TestCase
  test "valid fixtures" do
    assert memberships(:admin_on_startupoulu).valid?
    assert memberships(:editor_on_startupoulu).valid?
  end

  test "role must be editor or admin" do
    m = memberships(:editor_on_startupoulu)
    m.role = "superuser"
    assert_not m.valid?
  end

  test "admin? returns true only for admin role" do
    assert memberships(:admin_on_startupoulu).admin?
    assert_not memberships(:editor_on_startupoulu).admin?
  end

  test "user can only have one membership per site" do
    duplicate = Membership.new(user: users(:admin), site: sites(:startupoulu), role: "editor")
    assert_not duplicate.valid?
  end
end
