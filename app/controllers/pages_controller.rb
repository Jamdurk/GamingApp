class PagesController < ApplicationController
  def home
    @total_recordings = Recording.count
    @total_clips      = Clip.count
    @total_hours      = Recording.all.sum do |recording|
      if recording.video.attached?
        metadata = recording.video.blob.metadata
        seconds  = metadata.dig("custom", "asv_duration")&.to_f
        seconds.to_f / 3600
      else
        0
      end
    end
    @recent_recordings = Recording.order(created_at: :desc).limit(3)
  end
end