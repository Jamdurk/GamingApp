class ClipsController < ApplicationController
  def new
    @recording = Recording.find(params[:recording_id])
    @clip      = @recording.clips.build
  end

  def create
    @recording = Recording.find(params[:recording_id])
    @clip      = @recording.clips.build(clips_params)
    
    # Convert time strings to seconds for validation purposes
    @clip.start_time = timestamp_to_seconds(clips_params[:start_time]) if clips_params[:start_time].present?
    @clip.end_time   = timestamp_to_seconds(clips_params[:end_time]) if clips_params[:end_time].present?

    # Validates clip, doesnt save it. Clip generation service already saves it
    if @clip.valid?
      result = ClipGenerationService.call(
        recording: @recording,
        start_time: clips_params[:start_time], # Pass original string to service
        end_time: clips_params[:end_time],     # Pass original string to service  
        title: @clip.title
      )

      if result.success?
        redirect_to @recording, notice: 'Clip created successfully!'
      else
        @clip.errors.add(:base, result.error)
        render :new, status: :unprocessable_entity
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def clips_params
    params.require(:clip).permit(:title, :start_time, :end_time)
  end

  def timestamp_to_seconds(ts)
    parts = ts.split(":")                                
    parts[2] = parts[2].to_f                             
    parts.map.with_index { |v, idx| idx == 2 ? v : v.to_i } 
         .reverse                                        
         .each_with_index                                
         .sum { |v, idx| v * 60**idx }                   
  end
end