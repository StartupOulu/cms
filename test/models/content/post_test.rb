require "test_helper"

module Content
  class PostTest < ActiveSupport::TestCase
    BLOCKS = [ { "type" => "paragraph", "content" => "Body text." } ].freeze

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

    test "blocks is required" do
      post.blocks = nil
      assert_not post.valid?
    end

    test "slug must be unique within a site" do
      duplicate = Content::Post.new(site: site, user: users(:admin),
                                    title: "Another", slug: post.slug, blocks: BLOCKS)
      assert_not duplicate.valid?
    end

    test "slug is auto-generated from title" do
      p = Content::Post.new(site: site, user: users(:admin),
                            title: "Hello, World! 2024", blocks: BLOCKS)
      p.valid?
      assert_equal "hello-world-2024", p.slug
    end

    test "slug only allows lowercase letters, numbers, and hyphens" do
      post.slug = "Has Spaces"
      assert_not post.valid?
    end

    test "jekyll_path uses published_at date and slug" do
      post.published_at = Time.zone.parse("2026-04-01 10:00:00")
      assert_equal "_posts/2026-04-01-hello-world.markdown", post.jekyll_path
    end

    test "published? is false before publish" do
      p = Content::Post.new(site: site, user: users(:admin), title: "Draft", blocks: BLOCKS)
      assert_not p.published?
    end

    test "published? is true after published_at is set" do
      assert post.published?
    end

    # serialize_blocks

    test "serialize_blocks renders paragraphs" do
      post.blocks = [ { "type" => "paragraph", "content" => "Hello world." } ]
      assert_includes post.to_markdown, "Hello world."
    end

    test "serialize_blocks renders headings" do
      post.blocks = [ { "type" => "heading", "level" => 2, "content" => "Section" } ]
      assert_includes post.to_markdown, "## Section"
    end

    test "serialize_blocks renders unordered lists" do
      post.blocks = [ { "type" => "ul", "items" => [ "One", "Two" ] } ]
      assert_includes post.to_markdown, "- One\n- Two"
    end

    test "serialize_blocks renders ordered lists" do
      post.blocks = [ { "type" => "ol", "items" => [ "First", "Second" ] } ]
      assert_includes post.to_markdown, "1. First\n2. Second"
    end

    test "serialize_blocks joins multiple blocks with double newline" do
      post.blocks = [
        { "type" => "paragraph", "content" => "Intro." },
        { "type" => "heading",   "level" => 2, "content" => "Section" }
      ]
      assert_includes post.to_markdown, "Intro.\n\n## Section"
    end

    test "to_markdown includes layout and title in front matter" do
      md = post.to_markdown
      assert_includes md, "layout: blog"
      assert_includes md, "title: Hello World"
    end

    test "to_markdown includes description in front matter when present" do
      post.description = "A great post."
      assert_includes post.to_markdown, "description: A great post."
    end

    test "to_markdown omits description from front matter when blank" do
      post.description = nil
      assert_not_includes post.to_markdown, "description:"
    end

    # publish!

    test "publish! writes file to repo, sets published_at, and records audit event" do
      unpublished = Content::Post.create!(site: site, user: users(:admin),
                                          title: "Fresh Post", blocks: BLOCKS)

      with_git_site(site) do |clone|
        Current.site    = site
        Current.session = users(:admin).sessions.create!

        assert_difference "Audit::Event.count" do
          unpublished.publish!
        end

        assert unpublished.published?
        assert File.exist?(File.join(clone, unpublished.jekyll_path))

        event = Audit::Event.last
        assert_equal "publish",       event.action
        assert_equal "Content::Post", event.auditable_type
        assert_equal unpublished.id,  event.auditable_id
      end
    end

    test "publish! does not change published_at on a re-publish" do
      with_git_site(site) do
        Current.site    = site
        Current.session = users(:admin).sessions.create!

        original_published_at = post.published_at
        post.update!(blocks: [ { "type" => "paragraph", "content" => "Updated." } ])
        post.publish!

        assert_equal original_published_at, post.reload.published_at
      end
    end

    test "publish! snapshots blocks into published_blocks" do
      unpublished = Content::Post.create!(site: site, user: users(:admin),
                                          title: "Snappy Post", blocks: BLOCKS)
      with_git_site(site) do
        Current.site    = site
        Current.session = users(:admin).sessions.create!
        unpublished.publish!

        assert_equal BLOCKS, unpublished.reload.published_blocks
      end
    end

    test "publish! snapshots description and slug into published_fields" do
      unpublished = Content::Post.create!(site: site, user: users(:admin),
                                          title: "Snappy Post", blocks: BLOCKS,
                                          description: "A nice summary.")
      with_git_site(site) do
        Current.site    = site
        Current.session = users(:admin).sessions.create!
        unpublished.publish!

        assert_equal "A nice summary.", unpublished.reload.published_description
        assert_equal "snappy-post",     unpublished.reload.published_slug
      end
    end

    test "publish! deletes old file when slug is renamed" do
      with_git_site(site) do |clone|
        Current.site    = site
        Current.session = users(:admin).sessions.create!

        post.publish!
        old_path = File.join(clone, post.jekyll_path)
        assert File.exist?(old_path)

        post.update!(slug: "hello-world-renamed")
        post.publish!

        assert_not File.exist?(old_path), "old file should be removed on slug rename"
        assert File.exist?(File.join(clone, post.jekyll_path))
      end
    end

    test "pending_changes? is true when blocks differ from published_blocks" do
      post.blocks           = [ { "type" => "paragraph", "content" => "New." } ]
      post.published_blocks = [ { "type" => "paragraph", "content" => "Old." } ]
      assert post.pending_changes?
    end

    test "pending_changes? is false when blocks match published_blocks" do
      post.blocks = post.published_blocks = BLOCKS
      assert_not post.pending_changes?
    end

    # images

    test "publish! commits cover image to repo and adds blog_image to front matter" do
      with_git_site(site) do |clone|
        Current.site    = site
        Current.session = users(:admin).sessions.create!

        post.cover_image.attach(
          io:           File.open(Rails.root.join("test/fixtures/files/test.png")),
          filename:     "cover.png",
          content_type: "image/png"
        )
        post.publish!

        md = File.read(File.join(clone, post.jekyll_path))
        assert_includes md, "blog_image:"

        key = post.cover_image.blob.key
        assert File.exist?(File.join(clone, "assets/images/blogs/#{key}.png")),
               "cover image should be committed to the repo"
      end
    end

    test "publish! commits inline image block to repo and uses static path in markdown" do
      with_git_site(site) do |clone|
        Current.site    = site
        Current.session = users(:admin).sessions.create!

        blob = ActiveStorage::Blob.create_and_upload!(
          io:           File.open(Rails.root.join("test/fixtures/files/test.png")),
          filename:     "inline.png",
          content_type: "image/png"
        )
        post.update!(blocks: [
          { "type" => "paragraph", "content" => "Before." },
          { "type" => "image", "signed_id" => blob.signed_id, "url" => "/fake", "alt" => "A photo" }
        ])

        post.publish!

        md = File.read(File.join(clone, post.jekyll_path))
        assert_includes md, "![A photo]"
        assert_includes md, "assets/images/blogs/#{blob.key}.png"
        assert File.exist?(File.join(clone, "assets/images/blogs/#{blob.key}.png")),
               "inline image should be committed to the repo"
      end
    end

    # unpublish!

    test "unpublish! removes file from repo and clears published_at" do
      with_git_site(site) do |clone|
        Current.site    = site
        Current.session = users(:admin).sessions.create!

        post.publish!
        published_path = File.join(clone, post.jekyll_path)
        assert File.exist?(published_path)

        assert_difference "Audit::Event.count" do
          post.unpublish!
        end

        assert_not File.exist?(published_path)
        assert post.reload.draft?
        assert_nil post.reload.published_fields
        assert_nil post.reload.published_blocks
      end
    end
  end
end
