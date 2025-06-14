require "open3"
require "fileutils"
require "timeout"

class TranscriptionService
  def self.call(recording:)
    new(recording).call
  end

  def initialize(recording)
    @recording = recording
  end

  def call 
    # Stream directly from S3 - no local download needed!
    @recording.video.open do |video_tempfile|
      wav_path = convert_to_wav(video_tempfile.path)
      json_path = run_whisper(wav_path)
      result = parse_transcript(json_path)
      
      # Clean up temp files
      cleanup_temp_files([video_tempfile.path, wav_path, json_path])
      
      result
    end
  end

  private

  def convert_to_wav(input_path)
    # Generate unique filename to avoid conflicts
    timestamp = Time.current.to_i
    wav_path = "/tmp/audio_#{timestamp}_#{Process.pid}.wav"
    
    cmd = [
      "ffmpeg",
      "-i", input_path,
      "-ar", "16000",
      "-ac", "1",
      "-f", "wav",
      wav_path
    ]

    stdout, stderr, status = Open3.capture3(*cmd)
    unless status.success?
      cleanup_temp_files([wav_path])
      raise "FFmpeg failed: #{stderr}"
    end

    wav_path
  end

  def run_whisper(input_path)
    base_name = "whisper_#{Time.current.to_i}_#{Process.pid}"
    output_dir = "/tmp"
    model_path = Rails.root.join("whisper.cpp", "models", "ggml-large-v2.bin").to_s
  
    unless File.exist?(input_path) && File.readable?(input_path)
      raise "Input file does not exist or is not readable: #{input_path}"
    end
  
    cmd = [
      "./whisper.cpp/build/bin/whisper-cli",
      "-m", model_path,
      "-f", input_path,
      "-of", File.join(output_dir, base_name),
      "-otxt",
      "-oj",
      "-t", "4",
      "-ng" # Force cpu ONLY for fly.io
    ]
  
    puts "RUNNING: #{cmd.join(' ')}"

    Timeout::timeout(259200) do # 3 Days
      stdout, stderr, status = Open3.capture3(*cmd)
      puts "STDERR: #{stderr}"
      puts "STDOUT: #{stdout}"
      
      unless status.success?
        cleanup_temp_files([File.join(output_dir, "#{base_name}.json")])
        raise "Whisper.cpp failed: #{stderr}"
      end
    end
  
    json_path = File.join(output_dir, "#{base_name}.json")
    unless File.exist?(json_path)
      raise "Whisper JSON output not found: #{json_path}"
    end
  
    json_path
  rescue Timeout::Error
    cleanup_temp_files([File.join(output_dir, "#{base_name}.json")])
    raise "Whisper.cpp timed out after 3 days"
  end

  def parse_transcript(json_path)
    raw = File.read(json_path)
    data = JSON.parse(raw)

    segments = data["transcription"].map do |entry|
      {
        "start" => timecode_to_seconds(entry.dig("timestamps", "from")),
        "end"   => timecode_to_seconds(entry.dig("timestamps", "to")),
        "text"  => entry["text"]
      }
    end

    transcript = @recording.transcript || @recording.create_transcript!(data: data)
    transcript.segments.destroy_all

    segments.each do |seg|
      next if seg["text"].blank?
      transcript.segments.create!(
        start_time: seg["start"],
        end_time: seg["end"],
        text: seg["text"]
      )
    end
  end

  def cleanup_temp_files(file_paths)
    file_paths.each do |path|
      File.delete(path) if path && File.exist?(path)
    rescue => e
      Rails.logger.warn "Failed to cleanup temp file #{path}: #{e.message}"
    end
  end
 
  def timecode_to_seconds(str)
    return 0.0 if str.blank?
    parts = str.gsub(",", ".").split(":").map(&:to_f)
    (parts[0] * 3600) + (parts[1] * 60) + parts[2]
  end
end