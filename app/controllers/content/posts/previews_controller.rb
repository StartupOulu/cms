module Content
  module Posts
    class PreviewsController < ApplicationController
      before_action :set_post

      def show
        Current.site.jekyll_build_draft(@post)

        path = Current.site.jekyll_draft_output_path(@post)

        if path.nil?
          render plain: "Preview output not found — Jekyll may use a custom permalink.",
                 status: :not_found
          return
        end

        render html: File.read(path).html_safe, layout: false
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
