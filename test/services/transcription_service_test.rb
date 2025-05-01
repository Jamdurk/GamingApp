require "test_helper"
require "mocha/minitest"

class TranscriptionServiceTest < ActiveSupport::TestCase # Heavily AI generated, struggled alot with understanding how to test the transciption service, but for the sake of time i copies and pasted. I need to refer back to this at some stage to understand the content better.

    setup do 
        @transcript_service = recordings(:lethal_company)
    end

    test "parse_transcript method test" do
        fake_json_path = "test/fixtures/files/dummy_transcript.json"
        fake_wav_path  = "/tmp/fake.wav"

        # Fake run_whisper to just return this path instantly
        TranscriptionService.any_instance.stubs(:convert_to_wav).returns(fake_wav_path)
        TranscriptionService.any_instance.stubs(:run_whisper).returns(fake_json_path)
        

        result = TranscriptionService.call(recording: @transcript_service)

         assert_kind_of Array, result
         assert result.first[:start_time]
         assert result.first[:end_time]
         assert result.first[:text]
    end

    test "run_whisper constructs proper command" do
        service = TranscriptionService.new(@transcript_service)
        input_path = "/tmp/test_audio.wav"
        expected_json_path = "/tmp/test_audio.json"
        
        # Stub file existence and readability checks
        File.stubs(:exist?).with(input_path).returns(true)
        File.stubs(:readable?).with(input_path).returns(true)
        File.stubs(:exist?).with(expected_json_path).returns(true)
        
        # Stub the external command execution
        Open3.expects(:capture3).returns(["stdout", "", mock(success?: true)])
        
        result = service.send(:run_whisper, input_path)
        assert_equal expected_json_path, result
      end

      test "download_video creates temp file and copies recording content" do
        service = TranscriptionService.new(@transcript_service)
        
        # Create a mock file object
        mock_file = mock()
        mock_file.expects(:path).returns("/original/path/video.mp4")
        
        # Setup expectations
        temp_file_mock = mock()
        temp_file_mock.expects(:path).returns("/tmp/temp_recording_123.mp4").at_least_once
        
        Tempfile.expects(:new).with(['recording', '.mp4']).returns(temp_file_mock)
        @transcript_service.expects(:video).returns(mock_file_object = mock())
        mock_file_object.expects(:open).yields(mock_file)
        FileUtils.expects(:cp).with("/original/path/video.mp4", "/tmp/temp_recording_123.mp4")
        FileUtils.expects(:chmod).with(0644, "/tmp/temp_recording_123.mp4")
        
        # Run the method
        result = service.send(:download_video)
        
        # Assert the result
        assert_equal "/tmp/temp_recording_123.mp4", result
      end
      
      test "convert_to_wav builds ffmpeg command and executes it" do
        service = TranscriptionService.new(@transcript_service)
        input_path = "/tmp/recording.mp4"
        expected_output_path = "/tmp/recording.wav"
        
        # Set expectations for command execution
        expected_command = [
          "ffmpeg",
          "-i", input_path,
          "-ar", "16000",
          "-ac", "1",
          "-f", "wav",
          expected_output_path
        ]
        
        # Mock the execution to return success without actually running ffmpeg
        Open3.expects(:capture3).with(*expected_command).returns(["", "", mock(success?: true)])
        
        # Run the method
        result = service.send(:convert_to_wav, input_path)
        
        # Verify the result
        assert_equal expected_output_path, result
        
        # Test error handling
        Open3.unstub(:capture3)  # Remove previous stub
        Open3.expects(:capture3).with(*expected_command).returns(["", "Error occurred", mock(success?: false)])
        
        # Expect the method to raise an error when ffmpeg fails
        assert_raises(RuntimeError, "FFmpeg failed: Error occurred") do
          service.send(:convert_to_wav, input_path)
        end
      end

      test "timecode_to_seconds converts correctly" do
        service = TranscriptionService.new(@transcript_service)
      
        assert_equal 61.5, service.send(:timecode_to_seconds, "00:01:01,500")
        assert_equal 0.0,  service.send(:timecode_to_seconds, "")
        assert_equal 3661.0, service.send(:timecode_to_seconds, "01:01:01,000")
      end
      
      test "run_whisper raises error if whisper fails" do
        service = TranscriptionService.new(@transcript_service)
        input_path = "/tmp/test_audio.wav"
        expected_json_path = "/tmp/test_audio.json"
      
        # Stub file existence and readability checks
        File.stubs(:exist?).with(input_path).returns(true)
        File.stubs(:readable?).with(input_path).returns(true)
        File.stubs(:exist?).with(expected_json_path).returns(false) # Simulate whisper not generating output
      
        Open3.expects(:capture3).returns(["", "", mock(success?: true)])
      
        assert_raises(RuntimeError, /Whisper JSON output not found/) do
          service.send(:run_whisper, input_path)
        end
      end
      
      test "download_video handles missing video attachment" do
        service = TranscriptionService.new(@transcript_service)
      
        Tempfile.expects(:new).with(['recording', '.mp4']).returns(mock_tempfile = mock())
        mock_tempfile.stubs(:path).returns("/tmp/fake_tempfile.mp4")
        
        @transcript_service.expects(:video).returns(nil) # No video
        FileUtils.expects(:chmod).never
      
        assert_raises(NoMethodError) do
          service.send(:download_video)
        end
      end
      
      test "parse_transcript raises error on invalid JSON structure" do
        service = TranscriptionService.new(@transcript_service)
        invalid_json_path = "test/fixtures/files/invalid_transcript.json"
      
        File.write(invalid_json_path, '{"invalid":"structure"}') unless File.exist?(invalid_json_path)
      
        assert_raises(NoMethodError) do
          service.send(:parse_transcript, invalid_json_path)
        end
      
        File.delete(invalid_json_path) if File.exist?(invalid_json_path) # Clean up
      end
      
      test "call method raises if convert_to_wav fails" do
        TranscriptionService.any_instance.stubs(:convert_to_wav).raises(RuntimeError.new("conversion error"))
        TranscriptionService.any_instance.stubs(:download_video).returns("/tmp/fake_video.mp4")
      
        assert_raises(RuntimeError, /conversion error/) do
          TranscriptionService.call(recording: @transcript_service)
        end
      end
end

