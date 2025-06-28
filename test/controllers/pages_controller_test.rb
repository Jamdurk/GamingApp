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
    assert_select "nav a", count: 4  # Home, About, Recordings, Submission
  end

  test "home page displays total recording count" do
    recording_count = Recording.count

    get root_path

    assert_select "p", recording_count.to_s 
    assert_select "h5", "Total Recordings"
  end

  test "home page displays total clip count" do
    clip_count = Clip.count
    
    get root_path

    assert_select "p", clip_count.to_s
    assert_select "h5", "Total Clips"
  end

  test "home page displays total hours" do
    get root_path
    
    assert_select "h5", "Total Hours"
    assert_match /\d+\.\d+ hrs/, response.body  
  end

  test "home action sets correct instance variables" do
    get root_path

    assert_equal Recording.count, assigns(:total_recordings)
    assert_equal Clip.count, assigns(:total_clips)
  end

  test "home page displays recent recordings" do
    get root_path
    
    assert_select ".recent-section" do
      assert_select "h2", "🎯 Recent Gaming Sessions"
      assert_select ".recent-card", 3  
    end
  end





end

  

