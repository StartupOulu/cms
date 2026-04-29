require "test_helper"

module Content
  module Posts
    class PreviewsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @post = content_posts(:hello_world)
        @site = sites(:startupoulu)
        sign_in_as users(:admin)
      end

      test "GET /preview returns 503 when jekyll_port not configured" do
        @site.update_column(:jekyll_port, nil)
        get content_post_preview_path(@post)
        assert_response :service_unavailable
      end

      test "GET /preview writes draft file and returns 503 when Jekyll not running" do
        with_git_site(@site) do |clone|
          @site.update_column(:jekyll_port, 19999) # port nothing listens on

          get content_post_preview_path(@post)

          assert_response :service_unavailable
          assert File.exist?(File.join(clone, @post.draft_path)),
                 "draft file should be written even when Jekyll is not running"
        end
      end
    end
  end
end
