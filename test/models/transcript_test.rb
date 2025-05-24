require "test_helper"

class TranscriptTest < ActiveSupport::TestCase

  test "Transcript is invalid without associated recording" do
    transcript = Transcript.new(data: { "text" => "Hello, world! This is a test. This is another test. This is yet another test." })
  
    transcript.segments.build(start_time: 0, end_time: 10, text: "Hello, world!")
    transcript.segments.build(start_time: 10, end_time: 20, text: "This is a test")
    transcript.segments.build(start_time: 20, end_time: 30, text: "This is another test")
    transcript.segments.build(start_time: 30, end_time: 40, text: "This is yet another test")
  
    assert_not transcript.valid?
    assert_includes transcript.errors[:recording], "must exist"
  end

  test "Transcript is valid with associated recording" do
    recording = recordings(:lethal_company)
    attach_video(recording)

    transcript = recording.build_transcript(data: { "text" => "Hello, world! This is a test. This is another test. This is yet another test." })
  
    transcript.segments.build(start_time: 0, end_time: 10, text: "Hello, world!")
    transcript.segments.build(start_time: 10, end_time: 20, text: "This is a test")
    transcript.segments.build(start_time: 20, end_time: 30, text: "This is another test")
    transcript.segments.build(start_time: 30, end_time: 40, text: "This is yet another test")
  
    assert transcript.valid?
  end

  test "is invalid without data" do
    transcript = Transcript.new
    assert_not transcript.valid?
    assert_includes transcript.errors[:data], "can't be blank"
  end

  test "destroys associated segments when destroyed" do
    transcript = transcripts(:one)
    segment_ids = transcript.segments.pluck(:id)
    transcript.destroy
    segment_ids.each do |id|
      assert_nil Segment.find_by(id: id)
    end
  end
  





  

end
