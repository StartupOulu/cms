require "test_helper"

module Content
  class EventsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user  = users(:admin)
      @site  = sites(:startupoulu)
      @event = content_events(:tech_meetup)
      sign_in_as @user
    end

    test "GET /content/events" do
      get content_events_path
      assert_response :success
    end

    test "GET /content/events/new" do
      get new_content_event_path
      assert_response :success
    end

    test "GET /content/events/:id" do
      get content_event_path(@event)
      assert_response :success
    end

    test "POST /content/events saves draft and redirects to edit" do
      assert_difference "Content::Event.count" do
        post content_events_path, params: {
          content_event: {
            title:      "Summer Hackathon",
            start_time: "2026-08-01T10:00"
          }
        }
      end

      saved = Content::Event.last
      assert_redirected_to edit_content_event_path(saved)
      assert_equal "Event saved as draft.", flash[:notice]
      assert saved.draft?
    end

    test "POST /content/events with publish param publishes and redirects" do
      with_git_site(@site) do
        assert_difference "Content::Event.count" do
          post content_events_path, params: {
            publish: "1",
            content_event: {
              title:      "Live Event",
              start_time: "2026-09-01T14:00"
            }
          }
        end

        saved = Content::Event.last
        assert_redirected_to content_events_path
        assert_equal "Event published.", flash[:notice]
        assert saved.published?
      end
    end

    test "GET /content/events/:id/edit" do
      get edit_content_event_path(@event)
      assert_response :success
    end

    test "PATCH /content/events/:id updates the event" do
      patch content_event_path(@event), params: {
        content_event: {
          title:      "Updated Title",
          start_time: "2026-07-20T17:00",
          end_time:   "2026-07-20T20:00"
        }
      }
      assert_redirected_to edit_content_event_path(@event)
      assert_equal "Event saved.", flash[:notice]
      assert_equal "Updated Title", @event.reload.title
    end

    test "DELETE /content/events/:id destroys and redirects" do
      assert_difference "Content::Event.count", -1 do
        delete content_event_path(@event)
      end
      assert_redirected_to content_events_path
    end
  end
end
