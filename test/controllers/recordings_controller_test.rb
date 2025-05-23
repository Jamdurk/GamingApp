require "test_helper"

class RecordingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @match    = recordings(:lethal_company)
    @no_match = recordings(:for_clips) 
    @clip     = clips(:Vort)
  end

  test "should get index" do
    get recordings_path
    assert_response :success
  end

  test "should get show" do
    get recording_path(@match)
    assert_response :success
  end

  test "should return all recordings if no search param" do
    get recordings_path
    assert_response :success
    assert_includes assigns(:recordings), @match
    assert_includes assigns(:recordings), @no_match
  end

  test "should filter recordings by title or game_name when search param is present" do
    get recordings_path, params: { q: "mystring" }
    assert_response :success
    assert_includes assigns(:recordings), @match
    assert_not_includes assigns(:recordings), @no_match
  end

  test "should get show and display recording data and clips" do
    get recording_path(@no_match)
    assert_response :success

    assert_select "h1", @no_match.title

    assert_match @no_match.game_name, @response.body
    assert_match @no_match.players, @response.body

    assert_match @clip.title, @response.body
  end
  

  
end