module Content
  module Posts
    class AutosavesController < ApplicationController
      def update
        post = Current.site.content_posts.find(params[:post_id])
        blocks = JSON.parse(request.body.read).fetch("blocks")
        post.update_column(:blocks, blocks)
        render json: { ok: true }
      rescue JSON::ParserError, KeyError => e
        render json: { ok: false, error: e.message }, status: :unprocessable_entity
      end
    end
  end
end
