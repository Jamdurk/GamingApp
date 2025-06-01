class SubtitleGenerationJob < ApplicationJob
  queue_as :subtitles
  sidekiq_options retry: 3

  def perform(recording_id)
    recording = Recording.find_by(id: recording_id)
    return unless recording
    return unless recording.transcript.present?

    SubtitleGenerationService.call(recording: recording)

  rescue => e
    Rails.logger.error("Error in SubtitleGenerationJob: #{e.message}")
    raise e
  end
end