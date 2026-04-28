require "test_helper"

module Content
  module Posts
    class ImagesControllerTest < ActionDispatch::IntegrationTest
      setup do
        @post = content_posts(:hello_world)
        sign_in_as users(:admin)
      end

      test "POST /images uploads file and returns signed_id and url" do
        post content_post_images_path(@post), params: {
          file: fixture_file_upload("test.png", "image/png")
        }

        assert_response :success
        body = JSON.parse(response.body)
        assert body["signed_id"].present?
        assert body["url"].present?
      end

      test "POST /images rejects disallowed content type" do
        post content_post_images_path(@post), params: {
          file: fixture_file_upload("test.png", "text/plain")
        }
        assert_response :unprocessable_entity
      end
    end
  end
end
