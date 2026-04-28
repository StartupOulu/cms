require "test_helper"

module Content
  class PostsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:admin)
      @site = sites(:startupoulu)
      @post = content_posts(:hello_world)
      sign_in_as @user
    end

    # --- index ---

    test "GET /content/posts" do
      get content_posts_path
      assert_response :success
    end

    # --- new ---

    test "GET /content/posts/new" do
      get new_content_post_path
      assert_response :success
    end

    # --- create ---

    test "POST /content/posts publishes and redirects on success" do
      with_git_site(@site) do
        assert_difference "Content::Post.count" do
          post content_posts_path, params: {
            content_post: { title: "Brand New Post", body: "Hello world." }
          }
        end

        assert_redirected_to content_posts_path
        assert_equal "Post published.", flash[:notice]
        assert Content::Post.last.published?
      end
    end

    test "POST /content/posts re-renders new on invalid params" do
      post content_posts_path, params: { content_post: { title: "", body: "" } }
      assert_response :unprocessable_entity
    end

    test "POST /content/posts shows error when git publish fails" do
      # Clone path in the fixture doesn't point to a real git repo, so publish raises.
      post content_posts_path, params: {
        content_post: { title: "Failing Post", body: "Body." }
      }
      assert_response :unprocessable_entity
    end

    # --- edit ---

    test "GET /content/posts/:id/edit" do
      get edit_content_post_path(@post)
      assert_response :success
    end

    # --- update ---

    test "PATCH /content/posts/:id updates and redirects" do
      with_git_site(@site) do
        patch content_post_path(@post), params: {
          content_post: { title: "Updated Title", body: @post.body }
        }

        assert_redirected_to content_posts_path
        assert_equal "Updated Title", @post.reload.title
      end
    end

    # --- destroy (admin only) ---

    test "DELETE /content/posts/:id removes post" do
      assert_difference "Content::Post.count", -1 do
        delete content_post_path(@post)
      end
      assert_redirected_to content_posts_path
    end

    test "DELETE /content/posts/:id denied for editor" do
      sign_in_as users(:editor)
      assert_no_difference "Content::Post.count" do
        delete content_post_path(@post)
      end
      assert_redirected_to content_posts_path
    end

    # --- auth guard ---

    test "redirects unauthenticated requests to sign-in" do
      sign_out
      get content_posts_path
      assert_redirected_to new_session_path
    end
  end
end
