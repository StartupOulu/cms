require "application_system_test_case"

class PasswordChangesTest < ApplicationSystemTestCase
  test "new user is redirected to change password before accessing the app" do
    sign_in(email: "newhire@example.com", password: "temporarypass")
    assert_current_path edit_password_change_path
    assert_text "Set your password"
  end

  test "new user cannot bypass the password change screen" do
    sign_in(email: "newhire@example.com", password: "temporarypass")
    visit content_posts_path
    assert_current_path edit_password_change_path
  end

  test "setting a new password grants access to the app" do
    sign_in(email: "newhire@example.com", password: "temporarypass")

    fill_in "New password",         with: "mynewpassword123"
    fill_in "Confirm new password", with: "mynewpassword123"
    click_button "Set password"

    assert_current_path content_posts_path
    assert_text "Password updated"
  end

  test "mismatched passwords shows an error and stays on the change screen" do
    sign_in(email: "newhire@example.com", password: "temporarypass")

    fill_in "New password",         with: "password1"
    fill_in "Confirm new password", with: "different"
    click_button "Set password"

    assert_text "Passwords don't match"
    assert_no_current_path content_posts_path
  end

  test "blank password shows an error" do
    sign_in(email: "newhire@example.com", password: "temporarypass")

    disable_html5_validation
    fill_in "New password",         with: ""
    fill_in "Confirm new password", with: ""
    click_button "Set password"

    assert_text "can't be blank"
    assert_no_current_path content_posts_path
  end
end
