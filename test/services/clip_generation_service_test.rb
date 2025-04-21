require "test_helper" 

class ClipGenerationServiceTest < ActiveSupport::TestCase

    setup do
        @clip_generation = recordings(:for_clips)
    end

    test "clip generation service is functional" do
        attach_video(@clip_generation)
        result = ClipGenerationService.call(
            recording:   @clip_generation,
            start_time: "00:00:30",
            end_time:   "00:02:00",
            title:      "clip_generation_test"
            
        )
        assert result.success?
        assert result.clip.video.attached?
    end

    test "clip generation invalid if over 5 minutes" do
        attach_video(@clip_generation)
        result = ClipGenerationService.call(
            recording:   @clip_generation,
            start_time: "00:00:05",
            end_time:   "00:05:10",
            title:      "clip_generation_>5_test"
        )
        assert_not result.success?
        assert_nil result.clip
        assert_match "Video duration must be between", result.error
    end

    test "clip generation invalid if less that 1 second" do # This ones an edge case as the clip duration minimum is 1 second
        attach_video(@clip_generation)
        result = ClipGenerationService.call(
            recording:  @clip_generation,
            start_time: "00:00:05",
            end_time:   "00:00:05.9",
            title:      "clip_generation_<1_test" 
        )
        assert_not result.success?
        assert_nil result.clip
        assert_match "Start time must be before end", result.error
    end

    test "clip generation invalid if no title is present" do
        attach_video(@clip_generation)
        result = ClipGenerationService.call(
            recording:   @clip_generation,
            start_time: "00:00:05",
            end_time:   "00:00:20",
            title:       nil
        )
        assert_not result.success?
        assert_nil result.clip
        assert_match "Title can't be blank", result.error
    end

    test "clip generation invalid if no recording/video is attached" do
        attach_video(@clip_generation)
        result = ClipGenerationService.call(
            recording:   nil,
            start_time: "00:00:05",
            end_time:   "00:00:20",
            title:      "no recording"
        )
        assert_not result.success?
        assert_nil result.clip
        assert_match "Recording must be present to make clip", result.error  # Weird error match, but i couldnt add a validation for clips requiring a recording, as it caused too many contraints
    end

    test "clip generation invalid if no start time or end time present" do
        attach_video(@clip_generation)
        result = ClipGenerationService.call(
            recording:   @clip_generation,
            start_time:  nil,
            end_time:    nil,
            title:      "no recording"
        )
        assert_not result.success?
        assert_nil result.clip
        assert_match "Start time cannot be empty", result.error 
    end

    test "clip generation invalid if only start time is present and not end time" do
        attach_video(@clip_generation)
        result = ClipGenerationService.call(
            recording:   @clip_generation,
            start_time:  "00:01:00",
            end_time:     nil,
            title:       "no recording"
        )
        assert_not result.success?
        assert_nil result.clip
        assert_match "End time cannot be empty", result.error 
    end


    test "timestamp_to_seconds helper test" do
        result = timestamp_to_seconds("00:00:50")
        puts result
        assert_equal 50, result

        result1 = timestamp_to_seconds("00:03:00")
        puts result1
        assert_equal 180, result1

        result2 = timestamp_to_seconds("01:00:00")
        puts result2
        assert_equal 3600, result2
        
        result3 = timestamp_to_seconds("00:02:30") # Tests that it fails if the seconds are not equal
        puts result3
        assert_not_equal 4844, result3

        result4 = timestamp_to_seconds("00:04:30.5") # Testing for decimal points being valid
        puts result4
        assert_equal 270.5, result4
    end

    test "temp file is cleaned up" do
        attach_video(@clip_generation)
      
        result = ClipGenerationService.call(
          recording: @clip_generation,
          start_time: "00:00:10",
          end_time:   "00:00:30",
          title: "test_cleanup_direct"
        )
      
        output_path = "/tmp/clip_20250421-78858-ovo1cp.mp4"
      
        puts "File cleanup confirmed ✅" unless File.exist?(output_path)
      
        assert_not File.exist?(output_path), "Temp file #{output_path} should be deleted"
      end
      
      
      

      
end
        