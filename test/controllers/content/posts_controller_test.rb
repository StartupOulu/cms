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

    # --- create (draft) ---

    test "POST /content/posts saves draft and redirects to edit" do
      assert_difference "Content::Post.count" do
        post content_posts_path, params: {
          content_post: { title: "My Draft", body: "Hello world." }
        }
      end

      saved = Content::Post.last
      assert_redirected_to edit_content_post_path(saved)
      assert_equal "Draft saved.", flash[:notice]
      assert saved.draft?
    end

    # --- create (publish) ---

    test "POST /content/posts with publish param publishes and redirects" do
      with_git_site(@site) do
        assert_difference "Content::Post.count" do
          post content_posts_path, params: {
            publish: "1",
            content_post: { title: "Brand New Post", body: "Hello world." }
          }
        end

        assert_redirected_to content_posts_path
        assert_equal "Post published.", flash[:notice]
        assert Content::Post.last.published?
      end
    end

    test "POST /content/posts with publish saves draft and alerts when git fails" do
      # Fixture clone_path is not a real repo — publish raises PublishError.
      assert_difference "Content::Post.count" do
        post content_posts_path, params: {
          publish: "1",
          content_post: { title: "Failing Post", body: "Body." }
        }
      end
      saved = Content::Post.last
      assert_redirected_to edit_content_post_path(saved)
      assert saved.draft?
      assert_match "publish failed", flash[:alert]
    end

    test "POST /content/posts re-renders new on invalid params" do
      post content_posts_path, params: { content_post: { title: "", body: "" } }
      assert_response :unprocessable_entity
    end

    # --- edit ---

    test "GET /content/posts/:id/edit" do
      get edit_content_post_path(@post)
      assert_response :success
    end

    # --- update (draft) ---

    test "PATCH /content/posts/:id saves draft and redirects to edit" do
      patch content_post_path(@post), params: {
        content_post: { title: "Updated Title", body: @post.body }
      }

      assert_redirected_to edit_content_post_path(@post)
      assert_equal "Draft saved.", flash[:notice]
      assert_equal "Updated Title", @post.reload.title
    end

    # --- update (publish) ---

    test "PATCH /content/posts/:id with publish param publishes and redirects" do
      with_git_site(@site) do
        patch content_post_path(@post), params: {
          publish: "1",
          content_post: { title: "Updated Title", body: @post.body }
        }

        assert_redirected_to content_posts_path
        assert_equal "Post published.", flash[:notice]
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
