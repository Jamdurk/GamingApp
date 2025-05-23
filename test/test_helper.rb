ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "rails/test_help"
require "mocha/minitest"



module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)
    fixtures :all

    def attach_video(recording, filename: "test_attachment_check.mp4")
      recording.video.attach(
        io: File.open(Rails.root.join("test", "fixtures", "files", "recording_videos", filename)),
        filename: filename,
        content_type: "video/mp4"
      )
      
    end

    def attach_video_clip(clip, filename: "clip_test_generic.mp4")
      clip.video.attach(
        io: File.open(Rails.root.join("test", "fixtures", "files", "clip_videos", filename)),
        filename: filename,
        content_type: "video/mp4"
      )
      
    end

     # Convert "HH:MM:SS" → seconds. Simply placing the helper from our clip_generation_service in the testing env to allow testing
  def timestamp_to_seconds(ts)
    parts = ts.split(":")                                # Split timestamp "00:00:05.5" into array ["00","00","05.5"]
    parts[2] = parts[2].to_f                             # Convert seconds part to float to preserve decimals (5.5)
    parts.map.with_index { |v, idx| idx == 2 ? v : v.to_i } # Convert hours and minutes to integers, keep seconds as float
         .reverse                                        # Reverse to [5.5, 0, 0] (seconds, minutes, hours)
         .each_with_index                                # Create pairs with indices: [[5.5,0], [0,1], [0,2]]
         .sum { |v, idx| v * 60**idx }                   # Calculate: 5.5*60⁰ + 0*60¹ + 0*60² = 5.5 seconds
  end

   

  
  end
end
