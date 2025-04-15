require "test_helper"

class ClipTest < ActiveSupport::TestCase
  setup do
    @clip = clips(:Vort)
  end

  # Video upload tests
  test "clip should be invalid if greater than 5 minutes" do
    attach_video_clip(@clip, filename: "clip_greater_than_5.mp4")
    @clip.title = "clip title"
    assert_not @clip.valid?
  end

  test "clip should be valid if less than 5 minutes, but greater than 1 second" do
    attach_video_clip(@clip, filename: "clip_test_generic.mp4")
    @clip.title = "another clip title"
    assert @clip.valid?
  end

  test "clip is invalid if not mp4" do
    attach_video_clip(@clip, filename: "test_invalid_file.png")
    @clip.title = "third title"
    assert_not @clip.valid?
  end

  test "clip is invalid if under 1080p" do
    attach_video_clip(@clip, filename: "clip_480p.mp4")
    @clip.title = "fourth title"
    assert_not @clip.valid?
  end

  test "clip is invalid if unprocessable file" do 
    attach_video(@clip, filename: "test_unprocessable.mp4")
    @clip.title = "fifth title"
    assert_not @clip.valid?
  end

  # Clip attribute tests
  test "clip title should be present" do
    attach_video_clip(@clip)
    @clip.title = "   "
    assert_not @clip.valid?
  end

  test "start_time name should be present" do
    attach_video_clip(@clip)
    @clip.title = "sixth title"
    @clip.start_time = "  "
    assert_not @clip.valid?
  end

  test "end_time should be present" do
    attach_video_clip(@clip)
    @clip.title = "seventh Title"
    @clip.end_time = "  "
    assert_not @clip.valid?
  end

  test "clip title should not be too long" do
    attach_video_clip(@clip)
    @clip.title = "a" * 31
    assert_not @clip.valid?
  end

  test "start_time should not be equal or greater than end_time" do 
    attach_video_clip(@clip)
    # Checking if start time is greater than end time is invalid
    @clip.title = "last title"
    @clip.start_time = 22.seconds
    @clip.end_time   = 15.seconds
    assert_not @clip.valid?
    # Checking if start time is equal to end time is invalid
    @clip.start_time = 22.seconds
    @clip.end_time   = 22.seconds
    assert_not @clip.valid?
  end

  # Association test
  test "clips should belong to a recording" do
    assert_equal recordings(:for_clips), @clip.recording
  end
end
