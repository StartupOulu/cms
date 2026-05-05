module Content
  class EventsController < ApplicationController
    before_action :require_site
    before_action :set_event, only: %i[show edit update destroy]
    before_action :ensure_admin, only: %i[destroy]

    def index
      @events = Current.site.content_events.includes(:user).order(start_time: :desc)
    end

    def show
    end

    def new
      @event = Current.site.content_events.new
    end

    def create
      @event = Current.site.content_events.new(event_params)
      @event.user = Current.user

      if @event.save
        if params[:publish]
          begin
            @event.publish!
            redirect_to content_events_path, notice: "Event published."
          rescue PublishError => e
            redirect_to edit_content_event_path(@event), alert: "Saved, but publish failed: #{e.message}"
          end
        else
          redirect_to edit_content_event_path(@event), notice: "Event saved as draft."
        end
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @event.update(event_params)
        if params[:publish]
          begin
            @event.publish!
            redirect_to content_events_path, notice: "Event published."
          rescue PublishError => e
            @event.errors.add(:base, "Publish failed: #{e.message}")
            render :edit, status: :unprocessable_entity
          end
        else
          redirect_to edit_content_event_path(@event), notice: "Event saved."
        end
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @event.destroy
      redirect_to content_events_path, status: :see_other
    end

    private

    def set_event
      @event = Current.site.content_events.find(params[:id])
    end

    def event_params
      params.require(:content_event).permit(
        :title, :slug, :start_time, :end_time,
        :location, :excerpt, :description,
        :cta_title, :cta_link
      )
    end

    def require_site
      redirect_to root_path, alert: "No site configured." unless Current.site
    end

    def ensure_admin
      redirect_to content_events_path, alert: "Not authorized." unless Current.user.admin_of?(Current.site)
    end
  end
end
