class TranscriptionJob < ApplicationJob
  queue_as :default

  def perform(recording_id)
    recording = Recording.find_by(id: recording_id)
    return unless recording # Clause to make sure the service is not called if no recording is found
    return unless recording.video.attached? # Clause to make sure the service is not called if no video is present

    TranscriptionService.call(recording: recording)

    # Chain subtitles
    SubtitleGenerationJob.perform_later(recording_id)
  end
end

