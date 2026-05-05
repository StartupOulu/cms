module Content
  module Posts
    class PublicationsController < ApplicationController
      before_action :set_post

      def create
        @post.publish!
        redirect_to content_post_path(@post), notice: "Post published."
      rescue PublishError => e
        redirect_to content_post_path(@post), alert: "Publish failed: #{e.message}"
      end

      def destroy
        @post.unpublish!
        redirect_to content_post_path(@post), notice: "Post unpublished."
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
