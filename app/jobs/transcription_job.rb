class TranscriptionJob < ApplicationJob
  queue_as :transcription
  sidekiq_options retry: 3

  def perform(recording_id)
    recording = Recording.find_by(id: recording_id)
    return unless recording # Clause to make sure the service is not called if no recording is found
    return unless recording.video.attached? # Clause to make sure the service is not called if no video is present

    TranscriptionService.call(recording: recording)

    # Chain subtitles
    SubtitleGenerationJob.perform_later(recording_id)

  rescue => e
    Rails.logger.error("Error in TranscriptionJob: #{e.message}")
    raise e
  end
end

