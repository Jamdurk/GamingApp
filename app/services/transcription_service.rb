require "open3"
require "fileutils"
require "timeout"
include VideoUtils

class TranscriptionService
  def self.call(recording:)
    new(recording).call
  end

  def initialize(recording)
    @recording = recording
  end

  def call 
    input_path = download_video
    wav_path   = convert_to_wav(input_path)
    json_path  = run_whisper(wav_path)
    parse_transcript(json_path)
  end

  private

  def convert_to_wav(mp4_path)
    wav_path = mp4_path.sub(File.extname(mp4_path), ".wav")
    cmd = [
      "ffmpeg",
      "-i", mp4_path,
      "-ar", "16000",
      "-ac", "1",
      "-f", "wav",
      wav_path
    ]

    stdout, stderr, status = Open3.capture3(*cmd)
    raise "FFmpeg failed: #{stderr}" unless status.success?

    wav_path
  end

  def run_whisper(input_path)
    base_name  = File.basename(input_path, File.extname(input_path))
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
    raise "Whisper.cpp failed: #{stderr}" unless status.success?
  end
  
    json_path = File.join(output_dir, "#{base_name}.json")
    raise "Whisper JSON output not found: #{json_path}" unless File.exist?(json_path)

  
    json_path
    rescue Timeout::Error
      raise "Whisper.cpp timed out after 3 days"
  end

  def parse_transcript(json_path)
    raw  = File.read(json_path)
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
        end_time:   seg["end"],
        text:       seg["text"]
      )
    end
  end
 
  def timecode_to_seconds(str)
    return 0.0 if str.blank?
    parts = str.gsub(",", ".").split(":").map(&:to_f)
    (parts[0] * 3600) + (parts[1] * 60) + parts[2]
  end
end
