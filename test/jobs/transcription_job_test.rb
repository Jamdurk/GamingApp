require "test_helper"

class TranscriptionJobTest < ActiveJob::TestCase
 test "calls TranscriptionService with correct recording" do
   # Create new recording with video (fixtures can't have file attachments)
   recording = Recording.new(
     title: "Test Recording #{Time.now.to_i}",
     game_name: "Test Game", 
     players: "Test Player",
     date_played: Date.today
   )
   attach_video(recording)
   recording.save!
   
   # Verify the job calls both services
   TranscriptionService.expects(:call).with(recording: recording).once 
   SubtitleGenerationJob.expects(:perform_later).with(recording.id).once
 
   TranscriptionJob.perform_now(recording.id)
 end

 test "does not call services when video is missing" do
   recording = recordings(:lethal_company)
   recording.video.purge  # Remove any existing video
   
   # Verify the job exits early without calling services
   TranscriptionService.expects(:call).never
   SubtitleGenerationJob.expects(:perform_later).never

   TranscriptionJob.perform_now(recording.id)
 end

 test "does not call services when recording not found" do
   # Verify the job handles missing records gracefully
   TranscriptionService.expects(:call).never
   SubtitleGenerationJob.expects(:perform_later).never

   TranscriptionJob.perform_now(-1)
 end
end