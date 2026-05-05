require "application_system_test_case"

class DashboardTest < ApplicationSystemTestCase
  setup { sign_in }

  test "shows recent activity feed" do
    visit root_path

    assert_text "Recent activity"
    assert_text "Hello World"
    assert_text "published"
  end

  test "shows publish failure banner" do
    visit root_path

    assert_text "Publish failures"
    assert_text "Tech Meetup July 2026"
    assert_text "git push failed"
  end

  test "admin can dismiss publish failure banner" do
    visit root_path

    assert_text "Publish failures"
    click_button "Dismiss all"

    assert_current_path root_path
    assert_no_text "Publish failures"
  end

  test "editor sees failure banner but has no dismiss button" do
    sign_in(email: "editor@example.com", password: "password")
    visit root_path

    assert_text "Publish failures"
    assert_no_button "Dismiss all"
  end
end
