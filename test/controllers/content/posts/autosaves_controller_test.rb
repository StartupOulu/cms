require "test_helper"

module Content
  module Posts
    class AutosavesControllerTest < ActionDispatch::IntegrationTest
      setup do
        @post = content_posts(:hello_world)
        sign_in_as users(:admin)
      end

      test "PATCH autosave updates blocks and returns ok" do
        new_blocks = [ { "type" => "paragraph", "content" => "Autosaved." } ]

        patch content_post_autosave_path(@post),
              params:  { blocks: new_blocks }.to_json,
              headers: { "Content-Type" => "application/json" }

        assert_response :success
        assert_equal new_blocks, @post.reload.blocks
      end

      test "PATCH autosave returns error when blocks key is missing" do
        patch content_post_autosave_path(@post),
              params:  { other: "data" }.to_json,
              headers: { "Content-Type" => "application/json" }

        assert_response :unprocessable_entity
      end
    end
  end
end
