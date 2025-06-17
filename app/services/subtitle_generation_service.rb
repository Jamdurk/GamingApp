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
    original_size_gb = File.size(original_path) / 1.gigabyte.to_f
    Rails.logger.info "[SubtitleGeneration] Video downloaded to #{original_path} (#{original_size_gb.round(2)}GB)"

    Rails.logger.info "[SubtitleGeneration] Building SRT file..."
    srt_path = build_srt_file
    Rails.logger.info "[SubtitleGeneration] SRT file created at #{srt_path}"

    Rails.logger.info "[SubtitleGeneration] Burning subtitles with FFmpeg..."
    output_path = burn_subtitles_optimized(original_path, srt_path, original_size_gb)
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

  def burn_subtitles_optimized(input_path, srt_path, original_size_gb)
    output_path = Rails.root.join("tmp", "video_cache", "burned_#{@recording.id}_#{Time.now.to_i}.mp4").to_s
    FileUtils.mkdir_p(File.dirname(output_path))

    # Calculate appropriate CRF based on original file size
    # Larger files need more aggressive compression to stay under 5GB
    crf = calculate_crf_for_size(original_size_gb)
    
    Rails.logger.info "[SubtitleGeneration] Using CRF #{crf} for #{original_size_gb.round(2)}GB input"

    # CRITICAL: Use subtitles filter (NOT ass filter) to avoid libass dependency
    # The subtitles filter can handle SRT files with basic text rendering
    cmd = [
      "ffmpeg",
      "-y",
      "-i", input_path,
      "-vf", "subtitles=#{srt_path}:force_style='FontName=Arial,FontSize=24,PrimaryColour=&Hffffff,OutlineColour=&H000000,Outline=2'",
      "-c:v", "libx264",
      "-crf", crf.to_s,
      "-preset", "medium",         # Better compression than fast, not too slow
      "-profile:v", "high",
      "-level", "4.0", 
      "-threads", "12",
      "-c:a", "aac",
      "-b:a", "96k",
      "-movflags", "+faststart",
      "-max_muxing_queue_size", "4096",
      "-pix_fmt", "yuv420p",
      output_path
    ]

    Rails.logger.debug "[SubtitleGeneration] Running FFmpeg:\n#{cmd.join(' ')}"

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

    output_size_gb = File.size(output_path) / 1.gigabyte.to_f
    Rails.logger.info "[SubtitleGeneration] Initial FFmpeg output: #{File.size(output_path) / 1.megabyte}MB (#{output_size_gb.round(2)}GB)"
    
    # MANDATORY: Always check if file is too big for AWS
    if output_size_gb >= 4.5  # Conservative limit to ensure we stay under 5GB
      Rails.logger.warn "[SubtitleGeneration] File too large (#{output_size_gb.round(2)}GB), running emergency compression..."
      output_path = emergency_compress(output_path)
      
      # Double-check final size
      final_size_gb = File.size(output_path) / 1.gigabyte.to_f
      Rails.logger.info "[SubtitleGeneration] Final output after compression: #{File.size(output_path) / 1.megabyte}MB (#{final_size_gb.round(2)}GB)"
      
      if final_size_gb >= 4.8
        raise "File still too large for AWS after compression: #{final_size_gb.round(2)}GB"
      end
    end
    
    output_path
  rescue Timeout::Error
    raise "FFmpeg timed out after 10 hours"
  end

  def calculate_crf_for_size(original_size_gb)
    # More aggressive CRF scaling based on file size
    case original_size_gb
    when 0..1.0
      23  # High quality for small files
    when 1.0..2.0
      25  # Good quality
    when 2.0..3.0
      27  # Moderate compression
    when 3.0..4.0
      29  # More aggressive
    when 4.0..5.0
      31  # Very aggressive
    when 5.0..6.0
      33  # Extreme compression
    else
      35  # Maximum compression for huge files
    end
  end

  def emergency_compress(input_path)
    emergency_output = "#{input_path}.emergency"
    
    Rails.logger.info "[SubtitleGeneration] Starting emergency compression..."
    
    # Very aggressive settings as last resort
    emergency_cmd = [
      "ffmpeg", "-y",
      "-i", input_path,
      "-c:v", "libx264",
      "-crf", "32",              # Very high compression but not completely destroying quality
      "-preset", "slow",         # Good compression efficiency without being too slow
      "-profile:v", "main",      # Good compatibility
      "-level", "4.0",
      "-c:a", "aac",
      "-b:a", "64k",            # Very low audio bitrate
      "-movflags", "+faststart",
      "-pix_fmt", "yuv420p",
      emergency_output
    ]
    
    Rails.logger.debug "[SubtitleGeneration] Emergency compression command: #{emergency_cmd.join(' ')}"
    
    begin
      stdout, stderr, status = Open3.capture3(*emergency_cmd)
      unless status.success?
        Rails.logger.error "[SubtitleGeneration] Emergency compression failed: #{stderr}"
        raise "Emergency compression failed: #{stderr}"
      end
      
      unless File.exist?(emergency_output) && File.size(emergency_output) > 1000000
        raise "Emergency compression output missing or too small"
      end
      
      final_size_gb = File.size(emergency_output) / 1.gigabyte.to_f
      Rails.logger.info "[SubtitleGeneration] Emergency compression result: #{final_size_gb.round(2)}GB"
      
      if final_size_gb < 4.8  # Success
        File.delete(input_path)
        File.rename(emergency_output, input_path)
        Rails.logger.info "[SubtitleGeneration] ✅ Emergency compression successful: #{final_size_gb.round(2)}GB"
        return input_path
      else
        File.delete(emergency_output) if File.exist?(emergency_output)
        Rails.logger.error "[SubtitleGeneration] ❌ Even emergency compression failed: #{final_size_gb.round(2)}GB"
        raise "File too large even after emergency compression: #{final_size_gb.round(2)}GB"
      end
      
    rescue => e
      File.delete(emergency_output) if File.exist?(emergency_output)
      raise e
    end
  end

  def replace_video_safely(output_path)
    Rails.logger.debug "[SubtitleGeneration] Starting SAFE video replacement..."
    
    # Verify output file exists and has content
    unless File.exist?(output_path) && File.size(output_path) > 0
      raise "Output file is missing or empty: #{output_path}"
    end
    
    # Double-check file size before upload
    final_size_gb = File.size(output_path) / 1.gigabyte.to_f
    if final_size_gb >= 4.9
      raise "Final file too large for AWS: #{final_size_gb.round(2)}GB"
    end
    
    Rails.logger.info "[SubtitleGeneration] Uploading subtitled video (#{File.size(output_path) / 1.megabyte}MB)..."
    
    # Upload new video
    begin
      @recording.video.attach(
        io: File.open(output_path, "rb"),
        filename: "subtitled_#{@recording.title.parameterize}_#{@recording.id}.mp4",
        content_type: "video/mp4"
      )
      
      # Verify the new attachment succeeded
      @recording.reload
      if @recording.video.attached? && @recording.video.filename.to_s.include?("subtitled")
        Rails.logger.info "[SubtitleGeneration] ✅ New subtitled video successfully attached!"
        Rails.logger.info "[SubtitleGeneration] New video size: #{@recording.video.byte_size / 1.megabyte}MB"
      else
        raise "New video attachment verification failed"
      end
      
    rescue => e
      Rails.logger.error "[SubtitleGeneration] Failed to attach new video: #{e.message}"
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