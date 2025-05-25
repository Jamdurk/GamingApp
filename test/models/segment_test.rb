require "test_helper"

class SegmentTest < ActiveSupport::TestCase
  test "is invalid without transcript" do
    segment = Segment.new
    assert_not segment.valid?
    assert_includes segment.errors[:transcript], "must exist"
  end

  test "is valid with transcript" do
    transcript = transcripts(:one)
    segment = Segment.new(
      transcript: transcript,
      start_time: 0,
      end_time: 10,
      text: "Hello, world!"
    )
    assert segment.valid?
  end
  
  test "is invalid without start_time" do
    transcript = transcripts(:one)
    segment = Segment.new(
      transcript: transcript,
      start_time: nil,
      end_time: 10,
      text: "Hello, world!"
    )
    assert_not segment.valid?
    assert_includes segment.errors[:start_time], "can't be blank"
  end

  test "is invalid without end_time" do
    transcript = transcripts(:one)
    segment = Segment.new(
      transcript: transcript,
      start_time: 0,
      end_time: nil,
      text: "Hello, world!"
    )
    assert_not segment.valid?
    assert_includes segment.errors[:end_time], "can't be blank"
  end

  test "is invalid without text" do
    transcript = transcripts(:one)
    segment = Segment.new(
      transcript: transcript, 
      start_time: 0,
      end_time: 10,
      text: nil
    )
    assert_not segment.valid?
    assert_includes segment.errors[:text], "can't be blank"
  end

  test "is invalid when start_time is greater than end_time" do
    transcript = transcripts(:one)
    segment = Segment.new(
      transcript: transcript, 
      start_time: 5,
      end_time: 1,
      text: "Hello, world!"
    )
    assert_not segment.valid?    
    assert_includes segment.errors[:start_time], "must not be after end time"
  end
  
  test "is valid when start_time is equal to but not greater than end_time" do
    transcript = transcripts(:one)
    segment = Segment.new(
      transcript: transcript,
      start_time: 10,
      end_time: 10,
      text: "Hello, world!"
    )
    assert segment.valid?
  end
  
end
