class ClipsController < ApplicationController
  before_action :find_recording

  def new
    @clip = @recording.clips.build
  end

  def create
    @clip = @recording.clips.build(clips_params)

    # Convert “HH:MM:SS” to integer seconds for storage/validation
    if clips_params[:start_time].present?
      @clip.start_time = timestamp_to_seconds(clips_params[:start_time])
    end
    if clips_params[:end_time].present?
      @clip.end_time = timestamp_to_seconds(clips_params[:end_time])
    end


    if @clip.save
      # Enqueue the job that will call ClipGenerationService in the background
      ClipGenerationJob.perform_later(@clip.id)

      redirect_to @recording, notice: "Clip is being processed in the background."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def find_recording
    @recording = Recording.find_by(id: params[:recording_id])
    return redirect_to recordings_path, alert: "Recording not found" if @recording.nil?
  end

  def clips_params
    params.require(:clip).permit(:title, :start_time, :end_time)
  end

  def timestamp_to_seconds(ts)
    parts = ts.split(":")
    parts[2] = parts[2].to_f
    parts
      .map.with_index { |v, idx| idx == 2 ? v : v.to_i }
      .reverse
      .each_with_index
      .sum { |v, idx| v * 60**idx }
  end
end
