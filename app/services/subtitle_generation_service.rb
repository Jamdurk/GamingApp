require "open3"
require "fileutils"
require "timeout"
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

    Rails.logger.info "[SubtitleGeneration] Safely replacing video attachment..."
    replace_video_safely(output_path)
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
      # Better handling for large files
      "-movflags", "+faststart",
      "-max_muxing_queue_size", "4096",
      output_path
    ]

    Rails.logger.debug "[SubtitleGeneration] Running FFmpeg:\n#{cmd.join(' ')}"

    # Increased timeout for large files (4 hours should be plenty)
    Timeout::timeout(36000) do 
      stdout, stderr, status = Open3.capture3(*cmd)
      unless status.success?
        Rails.logger.error "[SubtitleGeneration] FFmpeg failed: #{stderr}"
        raise "FFmpeg failed: #{stderr}"
      end
    end

    # Verify output exists and is reasonable size
    unless File.exist?(output_path) && File.size(output_path) > 1000000
      raise "FFmpeg output missing or too small"
    end

    Rails.logger.info "[SubtitleGeneration] FFmpeg output: #{File.size(output_path) / 1.megabyte}MB"
    output_path
  rescue Timeout::Error
    raise "FFmpeg timed out after 4 hours"
  end

  # FIXED: Upload new video BEFORE deleting original
  def replace_video_safely(output_path)
    Rails.logger.debug "[SubtitleGeneration] Starting SAFE video replacement..."
    
    # Verify output file exists and has content
    unless File.exist?(output_path) && File.size(output_path) > 0
      raise "Output file is missing or empty: #{output_path}"
    end
    
    # Store reference to current video (in case we need to restore)
    current_video_key = @recording.video.key if @recording.video.attached?
    
    Rails.logger.info "[SubtitleGeneration] Uploading subtitled video (#{File.size(output_path) / 1.megabyte}MB)..."
    
    # STEP 1: Upload new video WITHOUT deleting old one yet
    begin
      @recording.video.attach(
        io: File.open(output_path, "rb"),
        filename: "subtitled_#{@recording.title.parameterize}_#{@recording.id}.mp4",
        content_type: "video/mp4"
      )
      
      # STEP 2: Verify the new attachment succeeded
      @recording.reload
      if @recording.video.attached? && @recording.video.filename.to_s.include?("subtitled")
        Rails.logger.info "[SubtitleGeneration] ✅ New subtitled video successfully attached!"
        Rails.logger.info "[SubtitleGeneration] New video size: #{@recording.video.byte_size / 1.megabyte}MB"
        
        # STEP 3: Only NOW is it safe to clean up the old video
      
        
      else
        raise "New video attachment verification failed"
      end
      
    rescue => e
      Rails.logger.error "[SubtitleGeneration] Failed to attach new video: #{e.message}"
      # If attachment failed, original video should still be intact
      raise "Video replacement failed: #{e.message}"
    end
    
    Rails.logger.debug "[SubtitleGeneration] ✅ Safe video replacement completed successfully"
  end

  def cleanup_temp_files(*paths)
    paths.compact.each do |path|
      if File.exist?(path)
        File.delete(path)
        Rails.logger.debug "[SubtitleGeneration] Cleaned up: #{path}"
      end
    end
  end

  def success
    Result.new(success?: true)
  end

  def failure(msg)
    Result.new(success?: false, error: msg)
  end
end