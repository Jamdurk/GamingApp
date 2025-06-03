class ClipGenerationJob < ApplicationJob
    queue_as :clips
    sidekiq_options retry: 3
  
    def perform(clip_id)
      clip = Clip.find_by(id: clip_id)
      return unless clip
  
      # Build HH:MM:SS strings from integer seconds if needed:
      hhmmss = ->(secs) {
        h = secs / 3600
        m = (secs % 3600) / 60
        s = secs % 60
        format("%02d:%02d:%02d", h, m, s)
      }
  
      ClipGenerationService.call(
        recording:  clip.recording,
        start_time: hhmmss.call(clip.start_time),
        end_time:   hhmmss.call(clip.end_time),
        title:      clip.title,
        clip:       clip  # Pass the existing clip!
      )
  
    rescue => e
      Rails.logger.error("Error in ClipGenerationJob: #{e.message}")
      raise e
    end
  end