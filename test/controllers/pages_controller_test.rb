require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest

  test "should get home" do
    get root_path
    assert_select "h1", "Gaming App 2025"
    assert_response :success
  end

end

  

