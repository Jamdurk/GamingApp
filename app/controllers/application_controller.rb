class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern


# Basically if someone is dumb and tries to put the url directly with some random recording ID that doesnnt exist this redirects and handles it rather than a 404
def find_recording
  @recording = Recording.find(params[:recording_id] || params[:id])
rescue ActiveRecord::RecordNotFound
  redirect_to recordings_path, alert: "Recording not found"
end

end
