require "net/http"

module Content
  module Posts
    class PreviewsController < ApplicationController
      before_action :set_post

      def show
        unless Current.site.jekyll_available?
          render plain: "Preview is not configured for this site (no jekyll_port set).",
                 status: :service_unavailable
          return
        end

        Current.site.write_draft(@post)

        uri = URI(Current.site.jekyll_draft_url(@post))

        begin
          http_response = Net::HTTP.get_response(uri)
        rescue Errno::ECONNREFUSED, SocketError
          render plain: "Preview server is not running. " \
                        "Start Jekyll with: jekyll serve --drafts --port #{Current.site.jekyll_port}",
                 status: :service_unavailable
          return
        end

        render html: http_response.body.html_safe, layout: false, status: http_response.code.to_i
      end

      private

      def set_post
        @post = Current.site.content_posts.find(params[:post_id])
      end
    end
  end
end
