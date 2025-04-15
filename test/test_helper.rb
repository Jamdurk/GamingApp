ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"



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

   

  
  end
end
