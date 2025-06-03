class RecordingProcessingJob < ApplicationJob
  queue_as :recording_processing
  sidekiq_options retry: 3

  def perform(recording_id)
    recording = Recording.find_by(id: recording_id)
    return unless recording && recording.video.attached?

    # Download the attached file into a Tempfile
    video_tempfile = Tempfile.new(['recording_', '.mp4'], binmode: true)
    video_tempfile.write(recording.video.download)
    video_tempfile.rewind

    # Re-attach from the Tempfile (if you need an attachment step)
    # recording.video.attach(
    #   io:           File.open(video_tempfile.path, 'rb'),
    #   filename:     "processed_#{recording.video.filename}",
    #   content_type: recording.video.content_type
    # )

    # Queue other processing (analyze, transcription, etc.)
    recording.video.analyze_later
    TranscriptionJob.perform_later(recording_id)

  ensure
    video_tempfile&.close
    video_tempfile&.unlink
  end
end
