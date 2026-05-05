require "application_system_test_case"

class SessionsTest < ApplicationSystemTestCase
  test "signs in with valid credentials and lands on posts" do
    sign_in
    assert_current_path content_posts_path
    assert_text "Posts"
  end

  test "stays on sign-in page with wrong password" do
    visit new_session_path
    fill_in "Email",    with: "admin@example.com"
    fill_in "Password", with: "wrongpassword"
    click_button "Sign in"
    assert_current_path new_session_path
    assert_no_text "Posts"
  end

  test "signs out and returns to sign-in" do
    sign_in
    click_button "Sign out"
    assert_current_path new_session_path
  end

  test "unauthenticated visit redirects to sign-in" do
    visit content_posts_path
    assert_current_path new_session_path
  end
end
