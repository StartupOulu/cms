module Content
  module Events
    class CoverImagesController < ApplicationController
      before_action :set_event

      def update
        file = params.require(:file)
        @event.cover_image.attach(file)

        if @event.cover_image.attached?
          render json: { url: url_for(@event.cover_image) }
        else
          render json: { error: "Upload failed." }, status: :unprocessable_entity
        end
      end

      def destroy
        @event.cover_image.purge
        head :no_content
      end

      private

      def set_event
        @event = Current.site.content_events.find(params[:event_id])
      end
    end
  end
end
