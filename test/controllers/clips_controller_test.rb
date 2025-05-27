require "test_helper"

class ClipsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get clips_new_url
    assert_response :success
  end

  test "should get create" do
    get clips_create_url
    assert_response :success
  end
end
