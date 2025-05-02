require "test_helper"

class SubtitleGenerationServiceTest < ActiveSupport::TestCase

  setup do
    @recording = recordings(:lethal_company)
    @service   = SubtitleGenerationService.new(@recording)
  end

  test "formats time correctly for whole seconds" do
    assert_equal "00:00:05,000", @service.send(:format_time, 5.0)
  end

  test "formats time correctly with milliseconds" do
    assert_equal "00:00:12,340", @service.send(:format_time, 12.34)
  end

  test "formats time correctly for longer durations" do
     result = assert_equal "01:02:03,210", @service.send(:format_time, 3723.21) 
  end

  test "builds a valid .srt file from segments" do
    transcript = Transcript.create!(recording: @recording, data: { fake: true }) # skip real JSON
    transcript.segments.create!(
      start_time: 1.5,
      end_time: 4.2,
      text: "Hello world"
    )
    transcript.segments.create!(
      start_time: 5.0,
      end_time: 7.5,
      text: "Welcome back!"
    )
  
    service  = SubtitleGenerationService.new(@recording)
    srt_path = service.send(:build_srt_file)
  
    assert File.exist?(srt_path)
  
    content = File.read(srt_path)
  
    expected = <<~SRT
      1
      00:00:01,700 --> 00:00:04,400
      Hello world
  
      2
      00:00:05,200 --> 00:00:07,700
      Welcome back!
    SRT
  
    assert_equal expected.strip, content.strip
  end
  
end
