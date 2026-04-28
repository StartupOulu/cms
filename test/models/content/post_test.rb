require "test_helper"

module Content
  class PostTest < ActiveSupport::TestCase
    def post
      content_posts(:hello_world)
    end

    def site
      sites(:startupoulu)
    end

    test "valid fixture" do
      assert post.valid?
    end

    test "title is required" do
      post.title = ""
      assert_not post.valid?
    end

    test "body is required" do
      post.body = ""
      assert_not post.valid?
    end

    test "slug must be unique within a site" do
      duplicate = Content::Post.new(site: site, user: users(:admin),
                                    title: "Another", slug: post.slug, body: "x")
      assert_not duplicate.valid?
    end

    test "slug is auto-generated from title" do
      p = Content::Post.new(site: site, user: users(:admin),
                            title: "Hello, World! 2024", body: "x")
      p.valid?
      assert_equal "hello-world-2024", p.slug
    end

    test "slug only allows lowercase letters, numbers, and hyphens" do
      post.slug = "Has Spaces"
      assert_not post.valid?
    end

    test "to_markdown includes front matter and body" do
      md = post.to_markdown
      assert_includes md, "layout: blog"
      assert_includes md, "title: Hello World"
      assert_includes md, post.body
    end

    test "jekyll_path uses published_at date and slug" do
      post.published_at = Time.zone.parse("2026-04-01 10:00:00")
      assert_equal "_posts/2026-04-01-hello-world.markdown", post.jekyll_path
    end

    test "published? is false before publish" do
      p = Content::Post.new(site: site, user: users(:admin), title: "Draft", body: "x")
      assert_not p.published?
    end

    test "published? is true after published_at is set" do
      assert post.published?
    end

    test "publish! writes file to repo, sets published_at, and records audit event" do
      unpublished = Content::Post.create!(site: site, user: users(:admin),
                                          title: "Fresh Post", body: "Body text.")

      with_git_site(site) do |clone|
        Current.site    = site
        Current.session = users(:admin).sessions.create!

        assert_difference "Audit::Event.count" do
          unpublished.publish!
        end

        assert unpublished.published?
        assert File.exist?(File.join(clone, unpublished.jekyll_path))

        event = Audit::Event.last
        assert_equal "publish",         event.action
        assert_equal "Content::Post",   event.auditable_type
        assert_equal unpublished.id,    event.auditable_id
      end
    end
  end
end
