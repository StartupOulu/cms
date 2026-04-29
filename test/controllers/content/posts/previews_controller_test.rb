require "test_helper"

module Content
  module Posts
    class PreviewsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @post = content_posts(:hello_world)
        @site = sites(:startupoulu)
        sign_in_as users(:admin)
      end

      test "GET /preview returns 503 when clone path is invalid" do
        @site.update_column(:clone_path, "/nonexistent/path")
        get content_post_preview_path(@post)
        assert_response :service_unavailable
      end

      test "GET /preview returns 503 when jekyll build fails" do
        with_git_site(@site) do
          # clone exists but has no _config.yml so jekyll build will fail
          get content_post_preview_path(@post)
          assert_response :service_unavailable
        end
      end
    end
  end
end
