Gaming Video Processing App
This is a Rails-based backend application that showcases video processing features built over 7 months of self-taught development. 
It includes services for clipping gameplay videos, transcribing audio to text, and burning subtitles into video using ffmpeg and whisper.cpp.

Ruby version
3.1.6

System dependencies:

ffmpeg — for video/audio conversion and processing

whisper.cpp — for local speech-to-text transcription

PostgreSQL — primary relational database

Redis — used by Sidekiq for background jobs

Configuration:

Ensure ffmpeg and whisper.cpp are installed and available in your system PATH

Configure AWS S3 credentials if using cloud storage (optional for local use)

Add your .env file or environment variables for credentials and paths (e.g., Whisper model path)

Database creation:

~rails db:create

Database initialization:
~rails db:migrate

How to run the test suite:

~rails test

All services and models have corresponding test suites to ensure functionality (over 100 tests currently).

Services:

ClipGenerationService: slices video into sub-clips based on user-defined timestamps using ffmpeg

TranscriptionService: transcribes full videos into text and timestamps using whisper.cpp

SubtitleGenerationService: burns subtitles into video based on transcription segments using ffmpeg

All services are executed via Sidekiq background jobs for asynchronous processing

Deployment instructions:

Ensure system dependencies (ffmpeg, whisper.cpp, redis, postgres) are installed on your server

Deploy app using Fly.io / Heroku / other preferred hosting

Start Sidekiq and Rails server:

~bundle exec sidekiq
~rails s

Upload a recording through the frontend or console — services will automatically process it in the background