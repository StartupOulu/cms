require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  CMS_NAME = Rails.application.config_for(:cms)[:name]

  test "page_title with no parts returns cms name and site host" do
    Current.site = sites(:startupoulu)
    assert_equal "#{CMS_NAME} – startupoulu.com", page_title
  end

  test "page_title prepends page-specific part" do
    Current.site = sites(:startupoulu)
    assert_equal "Edit Post – #{CMS_NAME} – startupoulu.com", page_title("Edit Post")
  end

  test "page_title with nil part omits it" do
    Current.site = sites(:startupoulu)
    assert_equal "#{CMS_NAME} – startupoulu.com", page_title(nil)
  end

  test "page_title with no site omits host segment" do
    Current.site = nil
    assert_equal CMS_NAME, page_title
  end

  test "page_title with no site and a part" do
    Current.site = nil
    assert_equal "Edit Post – #{CMS_NAME}", page_title("Edit Post")
  end
end
