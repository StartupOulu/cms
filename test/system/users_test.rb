require "application_system_test_case"

class UsersTest < ApplicationSystemTestCase
  test "admin sees Users link in nav" do
    sign_in
    assert_link "Users"
  end

  test "editor does not see Users link in nav" do
    sign_in(email: "editor@example.com", password: "password")
    assert_no_link "Users"
  end

  test "editor is redirected away from the users page" do
    sign_in(email: "editor@example.com", password: "password")
    visit users_path
    assert_no_current_path users_path
  end

  test "admin sees the existing users listed" do
    sign_in
    visit users_path

    assert_text "admin@example.com"
    assert_text "editor@example.com"
  end

  test "admin creates a new user and sees the temporary password" do
    sign_in
    visit new_user_path

    fill_in "Email",                   with: "newperson@example.com"
    fill_in "Display name (optional)", with: "New Person"
    select  "Editor",                  from: "Role"

    click_button "Create user"

    assert_text "User created"
    assert_text "newperson@example.com"
    # Temporary password is displayed (12 alphanumeric chars)
    assert_text "Temporary password"
  end

  test "admin cannot create a user with a duplicate email" do
    sign_in
    visit new_user_path

    fill_in "Email", with: "editor@example.com"  # already exists
    click_button "Create user"

    assert_text "Email address on jo käytössä"
    assert_current_path new_user_path
  end

  test "admin cannot create a user without an email" do
    sign_in
    visit new_user_path

    disable_html5_validation
    click_button "Create user"

    assert_text "Email address ei voi olla tyhjä"
  end
end
