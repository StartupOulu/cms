require "test_helper"

module Content
  class EventTest < ActiveSupport::TestCase
    def event
      content_events(:tech_meetup)
    end

    test "valid fixture" do
      assert event.valid?
    end

    test "title is required" do
      event.title = ""
      assert_not event.valid?
      assert event.errors[:title].any?
    end

    test "start_time is required" do
      event.start_time = nil
      assert_not event.valid?
      assert event.errors[:start_time].any?
    end

    test "slug must be unique within site" do
      duplicate = Content::Event.new(
        site: event.site,
        user: event.user,
        title: "Another event",
        slug: event.slug,
        start_time: 1.week.from_now
      )
      assert_not duplicate.valid?
      assert duplicate.errors[:slug].any?
    end

    test "slug allows same value on different site" do
      other_site = Site.create!(
        name: "Other", slug: "other-site", repo_url: "git@github.com:x/y.git",
        branch: "main", site_url: "https://other.example.com",
        publish_author_name: "Bot", publish_author_email: "bot@example.com",
        clone_path: "/tmp/other-site"
      )
      duplicate = Content::Event.new(
        site: other_site,
        user: event.user,
        title: "Same slug",
        slug: event.slug,
        start_time: 1.week.from_now
      )
      assert duplicate.valid?
    end

    test "end_time must be after start_time" do
      event.end_time = event.start_time - 1.hour
      assert_not event.valid?
      assert event.errors[:end_time].any?
    end

    test "slug is auto-generated from title" do
      e = Content::Event.new(
        site: event.site, user: event.user,
        title: "Hello World Event", start_time: 1.week.from_now
      )
      e.valid?
      assert_equal "hello-world-event", e.slug
    end

    test "published? is false when published_at is nil" do
      assert_not event.published?
    end

    test "published? is true when published_at is set" do
      event.published_at = Time.current
      assert event.published?
    end

    test "jekyll_path uses start_time month and slug" do
      assert_equal "_events/2026-07-tech-meetup-july-2026.html", event.jekyll_path
    end

    test "to_markdown includes correct front matter fields" do
      md = event.to_markdown
      assert_includes md, "title: Tech Meetup July 2026"
      assert_includes md, "start_time: '2026-07-15 17:00:00'"
      assert_includes md, "end_time: '2026-07-15 20:00:00'"
      assert_includes md, "layout: event"
    end

    test "to_markdown omits nil and blank optional fields" do
      event.location    = nil
      event.description = nil
      event.cta_title   = nil
      event.cta_link    = nil
      md = event.to_markdown
      assert_not_includes md, "location:"
      assert_not_includes md, "cta_title:"
      assert_not_includes md, "cta_link:"
    end

    test "cover_image_path returns placeholder when no image attached" do
      assert_equal "/assets/images/events/event-placeholder.png", event.cover_image_path
    end

    test "to_html_body returns empty string when no description" do
      event.description = nil
      assert_equal "", event.to_html_body
    end

    test "to_html_body wraps description in paragraph" do
      event.description = "Come join us!"
      assert_equal "<p>Come join us!</p>", event.to_html_body
    end
  end
end
