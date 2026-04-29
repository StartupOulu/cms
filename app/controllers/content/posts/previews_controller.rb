module Content
  module Posts
    class PreviewsController < ApplicationController
      before_action :set_post

      def show
        html = Current.site.render_preview(@post)
        render html: html.html_safe, layout: false
      rescue PreviewError => e
        render plain: e.message, status: :service_unavailable
      end

      private

      def set_post
        @post = Current.site.content_posts.find(params[:post_id])
      end
    end
  end
end
