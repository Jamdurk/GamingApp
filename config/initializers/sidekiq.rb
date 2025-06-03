
require 'sidekiq-limit_fetch'


Sidekiq.configure_server do |config|
  config.on(:startup) do
    Sidekiq::Queue['transcription'].limit = 1
    Sidekiq::Queue['subtitles'].limit = 1
    Sidekiq::Queue['clips'].limit = 1
    Sidekiq::Queue['recording_processing'].limit = 1
  end
end