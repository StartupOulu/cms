module Content
  module Events
    class PublicationsController < ApplicationController
      before_action :set_event

      def create
        @event.publish!
        redirect_to content_events_path, notice: "Event published."
      rescue PublishError => e
        redirect_to content_event_path(@event), alert: "Publish failed: #{e.message}"
      end

      def destroy
        @event.unpublish!
        redirect_to content_events_path, notice: "Event unpublished."
      rescue PublishError => e
        redirect_to content_event_path(@event), alert: "Unpublish failed: #{e.message}"
      end

      private

      def set_event
        @event = Current.site.content_events.find(params[:event_id])
      end
    end
  end
end
