# Load Ruby libraries we need
require "open3"      # Run shell commands and capture output
require "fileutils"  # File operations
require "timeout"    # Set time limits on operations

class TranscriptionService
  # Class method - call this to use the service
  def self.call(recording:)
    new(recording).call
  end

  # Store the recording we're working with
  def initialize(recording)
    @recording = recording
  end

  # Main method that does all the transcription work
  def call 
    # Stream video directly from S3 - no local download needed!
    @recording.video.open do |video_tempfile|
      # Step 1: Convert video to WAV audio format
      wav_path = convert_to_wav(video_tempfile.path)
      
      # Step 2: Run Whisper AI to transcribe the audio
      json_path = run_whisper(wav_path)
      
      # Step 3: Parse the JSON results and save to database
      result = parse_transcript(json_path)
      
      # Step 4: Clean up all temporary files
      cleanup_temp_files([video_tempfile.path, wav_path, json_path])
      
      result  # Return the transcript result
    end
  end

  private

  # Convert video file to WAV audio format for Whisper
  def convert_to_wav(input_path)
    # Generate unique filename to avoid conflicts between processes
    timestamp = Time.current.to_i  # Current time as integer
    wav_path = "/tmp/audio_#{timestamp}_#{Process.pid}.wav"
    
    # Build FFmpeg command to extract audio
    cmd = [
      "ffmpeg",         # The program
      "-i", input_path, # Input video file
      "-ar", "16000",   # Audio sample rate (16kHz - required by Whisper)
      "-ac", "1",       # Audio channels (1 = mono)
      "-f", "wav",      # Output format (WAV)
      wav_path          # Output file path
    ]

    # Run FFmpeg command and capture output
    stdout, stderr, status = Open3.capture3(*cmd)
    unless status.success?
      cleanup_temp_files([wav_path])  # Clean up if failed
      raise "FFmpeg failed: #{stderr}"
    end

    wav_path  # Return path to WAV file
  end

  # Run Whisper.cpp to transcribe the audio file
  def run_whisper(input_path)
    # Create unique filenames for this transcription job
    base_name = "whisper_#{Time.current.to_i}_#{Process.pid}"
    output_dir = "/tmp"
    model_path = Rails.root.join("whisper.cpp", "models", "ggml-large-v2.bin").to_s
  
    # Make sure input file exists and is readable
    unless File.exist?(input_path) && File.readable?(input_path)
      raise "Input file does not exist or is not readable: #{input_path}"
    end
  
    # Build Whisper.cpp command
    cmd = [
      "./whisper.cpp/build/bin/whisper-cli",  # The Whisper executable
      "-m", model_path,                       # AI model file path
      "-f", input_path,                       # Input audio file
      "-of", File.join(output_dir, base_name), # Output file prefix
      "-otxt",                                # Output text format
      "-oj",                                  # Output JSON format
      "-t", "4",                              # Use 4 CPU threads
      "-ng",                                   # Force CPU only (no GPU) for fly.io
      "--no-timestamps",                       # Sometimes helps prevent repetition loops
      "--max-len", "0",                        # Disable max length restrictions that can cause loops
      "--word-thold", "0.01"                   # Lower word confidence threshold
    ]
  
    puts "RUNNING: #{cmd.join(' ')}"  # Log the command we're running

    # Run Whisper with 3 day timeout (very long audio files)
    Timeout::timeout(259200) do # 3 Days = 259200 seconds
      stdout, stderr, status = Open3.capture3(*cmd)
      puts "STDERR: #{stderr}"  # Log any error output
      puts "STDOUT: #{stdout}"  # Log standard output
      
      unless status.success?
        cleanup_temp_files([File.join(output_dir, "#{base_name}.json")])
        raise "Whisper.cpp failed: #{stderr}"
      end
    end
  
    # Check that JSON output file was created
    json_path = File.join(output_dir, "#{base_name}.json")
    unless File.exist?(json_path)
      raise "Whisper JSON output not found: #{json_path}"
    end
  
    json_path  # Return path to JSON results
  rescue Timeout::Error
    # Clean up if timeout occurred
    cleanup_temp_files([File.join(output_dir, "#{base_name}.json")])
    raise "Whisper.cpp timed out after 3 days"
  end

  # Parse the JSON transcript and save to database
  def parse_transcript(json_path)
    # Read the JSON file from disk
    raw = File.read(json_path)
    data = JSON.parse(raw)

    # Convert Whisper format to our format
    segments = data["transcription"].map do |entry|
      {
        "start" => timecode_to_seconds(entry.dig("timestamps", "from")),  # Convert "00:01:23" to seconds
        "end"   => timecode_to_seconds(entry.dig("timestamps", "to")),    # Convert "00:01:25" to seconds
        "text"  => entry["text"]                                          # The spoken text
      }
    end

    # Find existing transcript or create new one
    transcript = @recording.transcript || @recording.create_transcript!(data: data)
    
    # Delete any old segments (fresh start)
    transcript.segments.destroy_all

    # Save each segment to database
    segments.each do |seg|
      next if seg["text"].blank?  # Skip empty text segments
      transcript.segments.create!(
        start_time: seg["start"],  # When segment starts (in seconds)
        end_time: seg["end"],      # When segment ends (in seconds)
        text: seg["text"]          # What was said
      )
    end
  end

  # Delete temporary files to free up disk space
  def cleanup_temp_files(file_paths)
    file_paths.each do |path|
      File.delete(path) if path && File.exist?(path)  # Delete if path exists and file exists
    rescue => e
      # Log warning but don't crash if cleanup fails
      Rails.logger.warn "Failed to cleanup temp file #{path}: #{e.message}"
    end
  end
 
  # Convert time format "01:23:45.678" to seconds (5025.678)
  def timecode_to_seconds(str)
    return 0.0 if str.blank?  # Return 0 if no time given
    
    # Replace comma with dot for decimal, split by colons
    parts = str.gsub(",", ".").split(":").map(&:to_f)
    
    # Calculate total seconds: hours*3600 + minutes*60 + seconds
    (parts[0] * 3600) + (parts[1] * 60) + parts[2]
  end
end