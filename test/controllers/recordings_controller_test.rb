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

  test "should get new" do
    get new_recording_path
    assert_response :success
    assert_select "form"
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

  test "create with missing video shows error message" do
    post recordings_path, params: {
      recording: {
        title: "Test Title",
        game_name: "Test Game",
        players: "Test Player",
        date_played: Date.today
        # No video attached!
      }
    }
    
    assert_response :unprocessable_entity
    assert_select "#error_explanation"
    assert_match "Video can&#39;t be blank", response.body
  end

  test "create with blank title shows error" do
    post recordings_path, params: {
      recording: {
        title: "", 
        game_name: "Test Game",
        players: "Test Player",
        date_played: Date.today,
        video: fixture_file_upload(
          Rails.root.join("test/fixtures/files/recording_videos/test_attachment_check.mp4"),
          "video/mp4"
        )
      }
    }
    
    assert_response :unprocessable_entity
    assert_select "#error_explanation li", "Title can't be blank"
  end

  test "create with blank game_name shows error" do
    post recordings_path, params: {
      recording: {
        title: "Test Title",
        game_name: "",
        players: "Test Player",
        date_played: Date.today,
        video: fixture_file_upload(
          Rails.root.join("test/fixtures/files/recording_videos/test_attachment_check.mp4"),
          "video/mp4"
        )
      }
    }
    
    assert_response :unprocessable_entity
    assert_select "#error_explanation li", "Game name can't be blank"
  end

  test "create with no players shows error" do
    post recordings_path, params: {
      recording: {
        title: "Test Title",
        game_name: "Test Game",
        players: "",
        date_played: Date.today,
        video: fixture_file_upload(
          Rails.root.join("test/fixtures/files/recording_videos/test_attachment_check.mp4"),
          "video/mp4"
        )
      }
    }
    
    assert_response :unprocessable_entity
    assert_select "#error_explanation li", "Players can't be blank"
  end

  test "create with invalid video shows error" do
    post recordings_path, params: {
      recording: {
        title: "Test Title",
        game_name: "Test Game",
        players: "Test Player",
        date_played: Date.today,
        video: fixture_file_upload(
          Rails.root.join("test/fixtures/files/recording_videos/test_invalid_file.png"),
          "video/png"
        )
      }
    }
    
    assert_response :unprocessable_entity
    assert_select "#error_explanation li", "Video has an invalid content type (authorized content type is MP4)"
  end

  test "create with invalid file, that has mp4 extension shows error" do
    post recordings_path, params: {
      recording: {
        title: "Test Title",
        game_name: "Test Game",
        players: "Test Player",
        date_played: Date.today,
        video: fixture_file_upload(
          Rails.root.join("test/fixtures/files/recording_videos/test_unprocessable.mp4"),
          "video/mp4"
        )
      }
    }
    
    assert_response :unprocessable_entity
    assert_select "#error_explanation li", "Video has an invalid content type (authorized content type is MP4)"
  end

  test "create with video under 15 minutes shows error" do
    post recordings_path, params: {
      recording: {
        title: "Test Title",
        game_name: "Test Game",
        players: "Test Player",
        date_played: Date.today,
        video: fixture_file_upload(
          Rails.root.join("test/fixtures/files/recording_videos/test_less_than_15min.mp4"),
          "video/mp4"
        )
      }
    }
    
    assert_response :unprocessable_entity
    assert_select "#error_explanation li", /must be greater than 15 minutes/
  end

  test "create with valid recording redirects to show page" do
    post recordings_path, params: {
      recording: {
        title: "Epic Gaming Session",
        game_name: "Lethal Company", 
        players: "Me and the boys",
        date_played: Date.today,
        video: fixture_file_upload(
          Rails.root.join("test/fixtures/files/recording_videos/test_attachment_check.mp4"),
          "video/mp4"
        )
      }
    }
    
    assert_response :redirect
    follow_redirect!
    assert_match "Recording created! Processing in background.", response.body
    assert_match "Epic Gaming Session", response.body
  end

test "processing_message returns correct messages/status" do
  recording = recordings(:for_clips)
  
  # No transcript
  assert_equal "Transcription in progress... please check back shortly.", recording.processing_message
  
  # With transcript
  recording.create_transcript!(data: {test: "data"})
  assert_equal "Subtitles are being burned into the video... please check back shortly.", recording.processing_message
end

test "should handle missing recording for show action" do
  get recording_path(999999)  # Non-existent recording ID
  
  assert_redirected_to recordings_path
  assert_match "Recording not found", flash[:alert]
end

end