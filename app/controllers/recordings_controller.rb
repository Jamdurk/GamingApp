class RecordingsController < ApplicationController
  before_action :find_recording, only: [:show]

  def new
    @recording = Recording.new
  end

  def create
    @recording = Recording.new(recording_params)

    if @recording.save
      RecordingProcessingJob.perform_later(@recording.id)
      redirect_to @recording, notice: "Recording created! Processing in background."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def index
    if params[:q].present?
      query = "%#{params[:q].downcase}%"
      @recordings = Recording
                      .where("LOWER(title) LIKE ? OR LOWER(game_name) LIKE ? OR LOWER(players) LIKE ?",
                             query, query, query)
                      .order(created_at: :desc)
                      .page(params[:page]).per(9)
    else
      @recordings = Recording.order(created_at: :desc)
                             .page(params[:page]).per(9)
    end
  end

  def show
    @clips = @recording.clips
  end

  private

  def find_recording
    @recording = Recording.find_by(id: params[:id])
    return if @recording

    redirect_to recordings_path, alert: "Recording not found"
  end

  def recording_params
    params.require(:recording).permit(
      :title,
      :game_name,
      :date_played,
      :players,
      :video
    )
  end
end
