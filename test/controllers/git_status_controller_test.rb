require "test_helper"

class GitStatusControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @site  = sites(:startupoulu)
    sign_in_as @admin
  end

  test "GET /git_status succeeds" do
    get git_status_path
    assert_response :success
  end

  test "GET /git_status shows failed check when clone is missing" do
    @site.update_columns(clone_path: "/nonexistent/path")
    get git_status_path
    assert_response :success
    assert_select ".git-check--error", minimum: 1
  end

  test "GET /git_status shows all checks passing with valid clone" do
    with_git_site(@site) do
      get git_status_path
      assert_response :success
      assert_select ".git-check--error", count: 0
      assert_select ".git-check--ok", count: 3
    end
  end

  test "GET /git_status shows no sites for a non-admin user" do
    sign_in_as users(:editor)
    get git_status_path
    assert_response :success
    assert_select ".git-site", count: 0
  end
end
