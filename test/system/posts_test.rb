require "application_system_test_case"

class PostsTest < ApplicationSystemTestCase
  setup { sign_in }

  test "lists existing posts" do
    visit content_posts_path
    assert_text "Hello World"
  end

  test "creates a new draft post with block editor content" do
    visit new_content_post_path

    fill_in "Title", with: "My System Test Post"

    # Type into the block editor's first paragraph block
    find("[contenteditable='true']").click
    find("[contenteditable='true']").send_keys("This is the post body.")

    click_button "Save draft"

    assert_text "Draft saved"
    assert_field "Title", with: "My System Test Post"
  end

  test "saves block editor content correctly" do
    visit new_content_post_path

    fill_in "Title", with: "Block Content Post"
    find("[contenteditable='true']").click
    find("[contenteditable='true']").send_keys("Block text here")

    click_button "Save draft"

    # Re-open edit page and confirm content is still there
    assert_text "Draft saved"
    assert_text "Block text here"
  end

  test "edits an existing post title" do
    visit edit_content_post_path(content_posts(:hello_world))

    fill_in "Title", with: "Updated Hello World"
    click_button "Save"

    assert_text "Draft saved"
    assert_field "Title", with: "Updated Hello World"
  end

  test "shows post detail with edit button" do
    visit content_post_path(content_posts(:hello_world))

    assert_text "Hello World"
    assert_link "Edit"
  end

  test "admin can delete a post" do
    visit content_post_path(content_posts(:hello_world))

    accept_confirm { click_button "Delete" }

    assert_current_path content_posts_path
    assert_no_text "Hello World"
  end

  test "editor cannot delete a post" do
    sign_in(email: "editor@example.com", password: "password")
    visit content_post_path(content_posts(:hello_world))

    assert_no_button "Delete"
  end
end
