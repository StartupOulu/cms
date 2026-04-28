module Content
  module Posts
    class PublicationsController < ApplicationController
      before_action :set_post

      def destroy
        @post.unpublish!
        redirect_to content_posts_path, notice: "Post unpublished."
      rescue PublishError => e
        redirect_to content_post_path(@post), alert: "Unpublish failed: #{e.message}"
      end

      private

      def set_post
        @post = Current.site.content_posts.find(params[:post_id])
      end
    end
  end
end
