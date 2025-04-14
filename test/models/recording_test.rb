require "test_helper"

class RecordingTest < ActiveSupport::TestCase
 setup do 
  @recording = recordings(:lethal_company)
end

# Video upload testing

test "recorded with valid title, players, and long mp4 is valid" do
  @recording.title     = "Full Package"
  @recording.players   = "Nik"
  @recording.game_name = "Roblox"
  attach_video(@recording)
  assert @recording.valid?
end

test "recording is valid with an attached video" do
  attach_video(@recording)
  @recording.title = "Title"
  assert @recording.valid?
end

test "recording is not valid without an attached video" do
  @recording.title = "Cool title"
  assert_not @recording.valid?
end
  
test "recording invalid if video is under 15 minutes" do
  # Testing that the validation fails due to a video shorter than 15mins being attached
  attach_video(@recording, filename: "test_less_than_15min.mp4")
  @recording.title = "Wow Title"
  assert_not @recording.valid? 
  assert @recording.errors[:video].any?
end

test "recording is valid if video is over 15 minutes" do
  # Testing that the validation passes as the video is greater than 15mins
  attach_video(@recording)
   @recording.title = "Another Title"
    assert @recording.valid?
  end

  test "recording is invalid if not mp4" do
    attach_video(@recording, filename: "test_invalid_file.png")
    @recording.title = "Coolest Title"
      assert_not @recording.valid?
      assert @recording.errors.any?
    end

    test "recording is invalid if under 1080p" do
      attach_video(@recording, filename: "test_invalid_resolution.mp4")
      @recording.title = "Most Cool Title"
      assert_not @recording.valid?
    end

   test "recording is invalid if unprocessable file" do 
    attach_video(@recording, filename: "test_unprocessable.mp4")
    @recording.title = "Holy title"
      assert_not @recording.valid?
    end

    
    # Recording attribute testing 

    test "recording title should be present" do
      attach_video(@recording)
      @recording.title = "   "
      assert_not @recording.valid?
    end
  
    test "game name should be present" do
      attach_video(@recording)
      @recording.game_name = "  "
      assert_not @recording.valid?
    end

    test "players should be present" do
      attach_video(@recording)
      @recording.title = "Wowest Title"
      @recording.players = "  "
      assert_not @recording.valid?
    end

    test "recording title should not be too long" do
      attach_video(@recording)
      @recording.title = "a" * 26
      assert_not @recording.valid?
    end
  
    test "player names should not be too long" do
      attach_video(@recording)
      @recording.title = "Title of all time"
      @recording.players = "a" * 51
      assert_not @recording.valid?
    end 

    test "title should be unique" do 
      attach_video(@recording)
      duplicate_rec = @recording.dup
      attach_video(duplicate_rec)
      duplicate_rec.title = @recording.title
      @recording.save
      assert_not duplicate_rec.valid?
    end
end
