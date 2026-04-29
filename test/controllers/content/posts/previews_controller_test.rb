require "test_helper"

module Content
  module Posts
    class PreviewsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @post = content_posts(:hello_world)
        @site = sites(:startupoulu)
        sign_in_as users(:admin)
      end

      test "GET /preview returns 503 when layout is missing" do
        # clone_path has no _layouts directory → PreviewError
        @site.update_column(:clone_path, Dir.mktmpdir("cms-preview-test"))
        get content_post_preview_path(@post)
        assert_response :service_unavailable
      ensure
        FileUtils.rm_rf(@site.clone_path)
      end

      test "GET /preview renders HTML when layout exists" do
        dir = Dir.mktmpdir("cms-preview-test")
        FileUtils.mkdir_p(File.join(dir, "_layouts"))
        File.write(
          File.join(dir, "_layouts", "blog.html"),
          "<html><body>{{ content }}</body></html>"
        )
        @site.update_column(:clone_path, dir)

        get content_post_preview_path(@post)

        assert_response :success
        assert_match "<html>", response.body
      ensure
        FileUtils.rm_rf(dir)
      end
    end
  end
end
