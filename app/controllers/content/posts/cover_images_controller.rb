module Content
  module Posts
    class CoverImagesController < ApplicationController
      before_action :set_post

      def update
        file = params.require(:file)
        @post.cover_image.attach(file)

        if @post.cover_image.attached?
          render json: { url: url_for(@post.cover_image) }
        else
          render json: { error: "Upload failed." }, status: :unprocessable_entity
        end
      end

      def destroy
        @post.cover_image.purge
        head :no_content
      end

      private

      def set_post
        @post = Current.site.content_posts.find(params[:post_id])
      end
    end
  end
end
