module Content
  module Events
    class PreviewsController < ApplicationController
      before_action :set_event

      def show
        html = Current.site.render_preview(@event)
        render html: html.html_safe, layout: false
      rescue PreviewError => e
        render plain: e.message, status: :service_unavailable
      end

      private

      def set_event
        @event = Current.site.content_events.find(params[:event_id])
      end
    end
  end
end
