require "test_helper"
require "mocha/minitest"

class TranscriptionServiceTest < ActiveSupport::TestCase
  setup do 
    @recording = recordings(:lethal_company)
  end

  test "parse_transcript creates segments from valid JSON" do
    fake_json_path = "test/fixtures/files/dummy_transcript.json"
    service = TranscriptionService.new(@recording)

    result = service.send(:parse_transcript, fake_json_path)

    assert_kind_of Array, result
    assert result.first["start"]
    assert result.first["end"]
    assert result.first["text"]
  end

  test "run_whisper raises error if whisper output JSON is missing" do
    service = TranscriptionService.new(@recording)
    input_path = "/tmp/test_audio.wav"
    base_name = "whisper_123_456"
    json_path = "/tmp/#{base_name}.json"

    File.stubs(:exist?).with(input_path).returns(true)
    File.stubs(:readable?).with(input_path).returns(true)
    File.stubs(:exist?).with(json_path).returns(false)

    Open3.expects(:capture3).returns(["", "", mock(success?: true)])
    Time.stubs(:current).returns(Time.at(123))
    Process.stubs(:pid).returns(456)

    assert_raises(RuntimeError, /Whisper JSON output not found/) do
      service.send(:run_whisper, input_path)
    end
  end

  test "convert_to_wav builds ffmpeg command and executes it" do
    service = TranscriptionService.new(@recording)
    input_path = "/tmp/recording.mp4"
    timestamp = 1234567890
    wav_path = "/tmp/audio_#{timestamp}_99999.wav"

    Time.stubs(:current).returns(Time.at(timestamp))
    Process.stubs(:pid).returns(99999)

    expected_command = [
      "ffmpeg", "-i", input_path, "-ar", "16000", "-ac", "1", "-f", "wav", wav_path
    ]

    Open3.expects(:capture3).with(*expected_command).returns(["", "", mock(success?: true)])

    result = service.send(:convert_to_wav, input_path)
    assert_equal wav_path, result
  end

  test "timecode_to_seconds handles various formats" do
    service = TranscriptionService.new(@recording)

    assert_equal 61.5, service.send(:timecode_to_seconds, "00:01:01,500")
    assert_equal 0.0,  service.send(:timecode_to_seconds, "")
    assert_equal 3661.0, service.send(:timecode_to_seconds, "01:01:01,000")
  end

  test "call method raises if convert_to_wav fails" do
    # Build a minimal mock recording with .video.open
    mock_recording = mock("Recording")
    mock_video = mock("VideoAttachment")
    fake_tempfile = mock("Tempfile")
    fake_tempfile.stubs(:path).returns("/tmp/fake.mp4")
  
    mock_video.stubs(:open).yields(fake_tempfile)
    mock_recording.stubs(:video).returns(mock_video)
  
    # Force failure at convert_to_wav
    TranscriptionService.any_instance.stubs(:convert_to_wav).raises(RuntimeError.new("conversion error"))
  
    assert_raises(RuntimeError, /conversion error/) do
      TranscriptionService.call(recording: mock_recording)
    end
  end
end
  
