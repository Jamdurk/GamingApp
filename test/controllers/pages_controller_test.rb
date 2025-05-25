require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest

  test "should get home" do
    get root_path
    assert_select "h1", "Gaming App 2025"
    assert_response :success
  end

  test "home page displays title and navigation" do
    get root_path
    assert_select "h1", "Gaming App 2025"
    assert_select "nav a", count: 3  # Home, Recordings, Submission
  end

end

  

