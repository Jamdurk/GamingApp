require "test_helper"

  class SubtitleGenerationJobTest < ActiveJob::TestCase

   test "calls SubtitleGenerationService with correct recording" do
     recording = Recording.new(
       title: "Test Recording #{Time.now.to_i}",
       game_name: "Test Game", 
       players: "Test Player",
       date_played: Date.today
     )
     attach_video(recording)
     recording.save!
   
    transcript = recording.create_transcript!(data: { "text" => "Hello, world! This is a test. This is another test. This is yet another test." })
    transcript.segments.create!(start_time: 0, end_time: 10, text: "Hello, world!")
    transcript.segments.create!(start_time: 10, end_time: 20, text: "This is a test")
    transcript.segments.create!(start_time: 20, end_time: 30, text: "This is another test")
    transcript.segments.create!(start_time: 30, end_time: 40, text: "This is yet another test")
     
     SubtitleGenerationService.expects(:call).with(recording: recording).once
     
     SubtitleGenerationJob.perform_now(recording.id)
   end
   
   test "does not call service when recording not found" do
     SubtitleGenerationService.expects(:call).never
     
     SubtitleGenerationJob.perform_now(-1)
   end
   
   test "does not call service when recording has no transcript" do
     recording = recordings(:lethal_company)
     recording.transcript&.destroy  
     
     SubtitleGenerationService.expects(:call).with(recording: recording).never
     
     SubtitleGenerationJob.perform_now(recording.id)
   end
  end

