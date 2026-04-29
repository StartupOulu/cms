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

  # render_preview

  test "render_preview renders post content through layout" do
    post = content_posts(:hello_world)
    dir  = Dir.mktmpdir("cms-site-test")
    FileUtils.mkdir_p(File.join(dir, "_layouts"))
    File.write(
      File.join(dir, "_layouts", "blog.html"),
      "<html><head><title>{{ page.title }}</title></head><body>{{ content }}</body></html>"
    )
    site.update_column(:clone_path, dir)

    html = site.render_preview(post)

    assert_includes html, post.title
    assert_includes html, "<html>"
  ensure
    FileUtils.rm_rf(dir)
  end

  test "render_preview raises PreviewError when layout is missing" do
    post = content_posts(:hello_world)
    site.update_column(:clone_path, Dir.mktmpdir("cms-site-test"))

    assert_raises(PreviewError) { site.render_preview(post) }
  ensure
    FileUtils.rm_rf(site.clone_path)
  end

  test "render_preview walks layout inheritance chain" do
    post = content_posts(:hello_world)
    dir  = Dir.mktmpdir("cms-site-test")
    FileUtils.mkdir_p(File.join(dir, "_layouts"))
    File.write(File.join(dir, "_layouts", "default.html"),
               "<!DOCTYPE html><html><body>{{ content }}</body></html>")
    File.write(File.join(dir, "_layouts", "blog.html"),
               "---\nlayout: default\n---\n<article>{{ content }}</article>")
    site.update_column(:clone_path, dir)

    html = site.render_preview(post)

    assert_includes html, "<!DOCTYPE html>"
    assert_includes html, "<article>"
  ensure
    FileUtils.rm_rf(dir)
  end
end
