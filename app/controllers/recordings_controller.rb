class RecordingsController < ApplicationController

  def new 
    @recording = Recording.new
  end

  def create
    @recording = Recording.new(recording_params)

    if @recording.save
      # Enqueueyour backround job pipeline
      TranscriptionJob.perform_later(@recording.id)
      redirect_to @recording, notice: "Recording uploaded successfully. Transcription in progress"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def index
    if params[:q].present?
      query = "%#{params[:q].downcase}%"
      @recordings = Recording.where(
        "LOWER(title) LIKE ? OR LOWER(game_name) LIKE ? OR LOWER(players) LIKE ?",
        query,
        query,
        query
      ).order(created_at: :desc).page(params[:page]).per(9)
    else
      @recordings = Recording.order(created_at: :desc).page(params[:page]).per(9)
    end
  end
  
  def show
    @recording = Recording.find(params[:id])
    @clips = @recording.clips
  end
end





private

def recording_params
  params.require(:recording).permit(:title, :game_name, :date_played, :players, :video)
end
