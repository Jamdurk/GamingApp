class ClipsController < ApplicationController
  def new
    @recording = Recording.find(params[:recording_id])
    @clip      = @recording.clips.build
  end

  def create
    @recording = Recording.find(params[:recording_id])
    @clip      = @recording.clips.build(clips_params)

    if @clip.save 
      result = ClipGenerationService.call(
        recording: @recording,
        start_time: @clip.start_time,
        end_time: @clip.end_time,
        title: @clip.title
      )

      if result.success?
        redirect_to @recording, notice: 'Clip created successfully!'
      else
        @clip.errors.add(:base, result.error)
        render :new
      end
    else
      render :new
  end
end

private 

def clips_params
  params.require(:clip).permit(:title, :start_time, :end_time)
end

end
