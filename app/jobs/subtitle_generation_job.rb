class SubtitleGenerationJob < ApplicationJob
  queue_as :default

  def perform(recording_id)
    recording = Recording.find_by(id: recording_id)
    return unless recording
    return unless recording.transcript.present?

    SubtitleGenerationService.call(recording: recording)
  end
end