module Content
  module Posts
    class ImagesController < ApplicationController
      ALLOWED_TYPES = %w[image/jpeg image/png image/webp].freeze
      MAX_SIZE      = 10.megabytes

      def create
        post = Current.site.content_posts.find(params[:post_id])
        file = params.require(:file)

        unless ALLOWED_TYPES.include?(file.content_type)
          return render json: { error: "Only JPEG, PNG, and WebP images are allowed." },
                        status: :unprocessable_entity
        end

        if file.size > MAX_SIZE
          return render json: { error: "Image must be under 10 MB." },
                        status: :unprocessable_entity
        end

        blob = ActiveStorage::Blob.create_and_upload!(
          io:           file,
          filename:     file.original_filename,
          content_type: file.content_type
        )

        render json: {
          signed_id: blob.signed_id,
          url:       url_for(blob)
        }
      end
    end
  end
end
