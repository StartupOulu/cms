require "application_system_test_case"

class EventsTest < ApplicationSystemTestCase
  setup { sign_in }

  test "lists existing events" do
    visit content_events_path
    assert_text "Tech Meetup July 2026"
  end

  test "creates a new draft event with required fields" do
    visit new_content_event_path

    fill_in "Title", with: "Summer Startup Night"
    set_datetime "content_event[start_time]", "2026-08-15T18:00"

    click_button "Save draft"

    assert_text "Event saved as draft"
    assert_field "Title", with: "Summer Startup Night"
  end

  test "creates a new event with all optional fields" do
    visit new_content_event_path

    fill_in "Title",             with: "Full Details Event"
    set_datetime "content_event[start_time]", "2026-09-01T17:00"
    set_datetime "content_event[end_time]",   "2026-09-01T20:00"
    fill_in "Location (optional)",            with: "Oulu, Tellus Arena"
    fill_in "Excerpt (optional)",             with: "A short summary."
    fill_in "Description (optional)",         with: "The full description goes here."
    fill_in "Button label (optional)",        with: "Register now"
    fill_in "Button URL (optional)",          with: "https://example.com/register"

    click_button "Save draft"

    assert_text "Event saved as draft"
    assert_field "Title", with: "Full Details Event"
  end

  test "shows validation error when title is missing" do
    visit new_content_event_path

    set_datetime "content_event[start_time]", "2026-08-15T18:00"
    disable_html5_validation
    click_button "Save draft"

    assert_text "Title ei voi olla tyhjä"
    assert_current_path new_content_event_path
  end

  test "edits an existing event" do
    visit edit_content_event_path(content_events(:tech_meetup))

    fill_in "Title", with: "Tech Meetup August 2026"
    click_button "Save"

    assert_text "Event saved"
    assert_field "Title", with: "Tech Meetup August 2026"
  end

  test "shows event detail with edit and publish buttons" do
    visit content_event_path(content_events(:tech_meetup))

    assert_text "Tech Meetup July 2026"
    assert_link  "Edit"
    assert_button "Publish"
  end

  test "admin can delete an event" do
    visit content_event_path(content_events(:tech_meetup))

    accept_confirm { click_button "Delete" }

    assert_current_path content_events_path
    assert_no_text "Tech Meetup July 2026"
  end

  test "editor cannot delete an event" do
    sign_in(email: "editor@example.com", password: "password")
    visit content_event_path(content_events(:tech_meetup))

    assert_no_button "Delete"
  end
end
