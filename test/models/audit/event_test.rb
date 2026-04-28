require "test_helper"

module Audit
  class EventTest < ActiveSupport::TestCase
    test "valid fixture" do
      assert audit_events(:publish_hello_world).valid?
    end

    test ".record creates an audit event" do
      post = content_posts(:hello_world)
      site = sites(:startupoulu)
      user = users(:admin)

      assert_difference "Audit::Event.count" do
        Audit::Event.record("publish", auditable: post, site: site, user: user)
      end

      event = Audit::Event.last
      assert_equal "publish",         event.action
      assert_equal "Content::Post",   event.auditable_type
      assert_equal post.id,           event.auditable_id
      assert_equal site,              event.site
      assert_equal user,              event.user
    end

    test "action is required" do
      event = Audit::Event.new(site: sites(:startupoulu), user: users(:admin))
      assert_not event.valid?
    end
  end
end
