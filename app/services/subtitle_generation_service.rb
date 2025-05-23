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
    unless @recording.transcript.present?
      Rails.logger.warn "[SubtitleGeneration] No transcript found for recording #{@recording.id}"
      return failure("No transcript found")
    end

    Rails.logger.info "[SubtitleGeneration] Starting subtitle generation for recording #{@recording.id}"

    Rails.logger.info "[SubtitleGeneration] Downloading original video..."
    original_path = download_video
    Rails.logger.info "[SubtitleGeneration] Video downloaded to #{original_path}"

    Rails.logger.info "[SubtitleGeneration] Building SRT file..."
    srt_path = build_srt_file
    Rails.logger.info "[SubtitleGeneration] SRT file created at #{srt_path}"

    Rails.logger.info "[SubtitleGeneration] Burning subtitles with FFmpeg..."
    output_path = burn_subtitles(original_path, srt_path)
    Rails.logger.info "[SubtitleGeneration] FFmpeg completed. Output at #{output_path}"

    Rails.logger.info "[SubtitleGeneration] Replacing video attachment..."
    replace_video(output_path)
    Rails.logger.info "[SubtitleGeneration] Video replaced for recording #{@recording.id}"

    success
  rescue => e
    Rails.logger.error "[SubtitleGeneration] ERROR: #{e.message}\n#{e.backtrace.join("\n")}"
    failure(e.message)
  ensure
    cleanup_temp_files(original_path, srt_path, output_path)
    Rails.logger.info "[SubtitleGeneration] Temp files cleaned up for recording #{@recording.id}"
  end

  private

  def build_srt_file
    srt_file = Tempfile.new(["subtitles_", ".srt"])
    segments = @recording.transcript.segments.order(:start_time)

    offset = 0.2
    segments.each do |segment|
      segment.start_time += offset
      segment.end_time += offset
    end

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
      "-map", "0:v",
      "-map", "0:a",
      "-vf", "subtitles=#{srt_path}",
      "-c:v", "libx264",
      "-preset", "ultrafast",
      "-threads", "12",
      "-c:a", "copy",
      output_path
    ]

    Rails.logger.debug "[SubtitleGeneration] Running FFmpeg:\n#{cmd.join(' ')}"

    stdout, stderr, status = Open3.capture3(*cmd)
    unless status.success?
      Rails.logger.error "[SubtitleGeneration] FFmpeg failed: #{stderr}"
      raise "FFmpeg failed: #{stderr}"
    end

    output_path
  end

  def replace_video(output_path)
    Rails.logger.debug "[SubtitleGeneration] Purging existing video..." if @recording.video.attached?

    @recording.video.purge_later if @recording.video.attached?

    @recording.video.attach(
      io: File.open(output_path, "rb"),
      filename: "subtitled_#{@recording.id}.mp4",
      content_type: "video/mp4"
    )

    Rails.logger.debug "[SubtitleGeneration] New video attached: subtitled_#{@recording.id}.mp4"
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
