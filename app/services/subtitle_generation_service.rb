require "open3"
require "fileutils"
include VideoUtils

class SubtitleGenerationService
  Result = Struct.new(:success?, :error, keyword_init: true)

  def self.call(recording:)
    new(recording).call
  end

  def initialize(recording)
    @recording = recording
  end

  def call
    return failure("No transcript found") unless @recording.transcript.present?

    original_path = download_video
    srt_path      = build_srt_file
    output_path   = burn_subtitles(original_path, srt_path)

    replace_video(output_path)
    success
  rescue => e
    failure(e.message)
  ensure
    cleanup_temp_files(original_path, srt_path, output_path)
  end

  private

  def build_srt_file
    srt_file = Tempfile.new(["subtitles_", ".srt"])
    segments = @recording.transcript.segments.order(:start_time)

    segments.each_with_index do |segment, index|
      srt_file.write "#{index + 1}\n"
      srt_file.write "#{format_time(segment.start_time)} --> #{format_time(segment.end_time)}\n"
      srt_file.write "#{segment.text.strip}\n\n"
    end

    srt_file.close
    srt_file.path
  end

  def format_time(seconds)
    ms = ((seconds % 1) * 1000).round
    t  = Time.at(seconds).utc.strftime("%H:%M:%S")
    "#{t},#{ms.to_s.rjust(3, '0')}"
  end

  def burn_subtitles(input_path, srt_path)
    output_path = Tempfile.new(["burned_", ".mp4"]).path

    cmd = [
      "ffmpeg",
      "-y",
      "-i", input_path,
      "-vf", "subtitles=#{srt_path}",
      "-c:v", "libx264",
      "-preset", "ultrafast",
      "-threads", "12",
      "-c:a", "copy",
      output_path
    ]

    stdout, stderr, status = Open3.capture3(*cmd)
    raise "FFmpeg failed: #{stderr}" unless status.success?

    output_path
  end

  def replace_video(output_path)
    @recording.video.purge_later if @recording.video.attached?

    @recording.video.attach(
      io: File.open(output_path, "rb"),
      filename: "subtitled_#{@recording.id}.mp4",
      content_type: "video/mp4"
    )
  end

  def cleanup_temp_files(*paths)
    paths.compact.each do |path|
      File.delete(path) if File.exist?(path)
    end
  end

  def success
    Result.new(success?: true)
  end

  def failure(msg)
    Result.new(success?: false, error: msg)
  end
end
