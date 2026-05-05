require "test_helper"

module Content
  module Posts
    class PublicationsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @site = sites(:startupoulu)
        @post = content_posts(:hello_world)
        sign_in_as users(:admin)
      end

      test "DELETE unpublishes the post and redirects" do
        with_git_site(@site) do |clone|
          Current.site    = @site
          Current.session = users(:admin).sessions.create!

          @post.publish!
          assert File.exist?(File.join(clone, @post.jekyll_path))

          delete content_post_publication_path(@post)

          assert_redirected_to content_post_path(@post)
          assert_equal "Post unpublished.", flash[:notice]
          assert @post.reload.draft?
        end
      end

      test "DELETE redirects with alert when git fails" do
        # Fixture clone_path is not a real repo — unpublish raises PublishError.
        delete content_post_publication_path(@post)
        assert_redirected_to content_post_path(@post)
        assert_match "Unpublish failed", flash[:alert]
      end
    end
  end
end
