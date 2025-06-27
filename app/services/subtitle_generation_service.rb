# Load Ruby libraries we need
require "open3"      # Run shell commands and capture output
require "fileutils"  # File operations like mkdir, delete
require "timeout"    # Set time limits on operations
include VideoUtils   # Custom video helper methods

class SubtitleGenerationService
  # Simple result object to return success/failure
  Result = Struct.new(:success?, :error, keyword_init: true)

  # Class method - call this to use the service
  def self.call(recording:)
    new(recording).call
  end

  # Store the recording we're working with
  def initialize(recording)
    @recording = recording
  end

  # Main method that does all the work
  def call
    # Check if recording has a transcript first
    unless @recording.transcript.present?
      Rails.logger.warn "[SubtitleGeneration] No transcript found for recording #{@recording.id}"
      return failure("No transcript found")
    end

    Rails.logger.info "[SubtitleGeneration] Starting subtitle generation for recording #{@recording.id}"

    # Step 1: Download the original video file
    Rails.logger.info "[SubtitleGeneration] Downloading original video..."
    original_path = download_video
    original_size_gb = File.size(original_path) / 1.gigabyte.to_f  # Convert bytes to GB
    Rails.logger.info "[SubtitleGeneration] Video downloaded to #{original_path} (#{original_size_gb.round(2)}GB)"

    # Step 2: Create SRT subtitle file from transcript
    Rails.logger.info "[SubtitleGeneration] Building SRT file..."
    srt_path = build_srt_file
    Rails.logger.info "[SubtitleGeneration] SRT file created at #{srt_path}"

    # Step 3: Use FFmpeg to burn subtitles into video
    Rails.logger.info "[SubtitleGeneration] Burning subtitles with FFmpeg..."
    output_path = burn_subtitles_optimized(original_path, srt_path, original_size_gb)
    Rails.logger.info "[SubtitleGeneration] FFmpeg completed. Output at #{output_path}"

    # Step 4: Replace original video with subtitled version
    Rails.logger.info "[SubtitleGeneration] Safely replacing video attachment..."
    replace_video_safely(output_path)
    Rails.logger.info "[SubtitleGeneration] Video replaced for recording #{@recording.id}"

    # Return success
    success
  rescue => e
    # If anything goes wrong, log error and return failure
    Rails.logger.error "[SubtitleGeneration] ERROR: #{e.message}\n#{e.backtrace.join("\n")}"
    failure(e.message)
  ensure
    # Always clean up temp files, even if there was an error
    cleanup_temp_files(original_path, srt_path, output_path)
    Rails.logger.info "[SubtitleGeneration] Temp files cleaned up for recording #{@recording.id}"
  end

  private

  # Create SRT subtitle file from transcript segments
  def build_srt_file
    # Create temporary SRT file
    srt_file = Tempfile.new(["subtitles_", ".srt"])
    # Get transcript segments in time order
    segments = @recording.transcript.segments.order(:start_time)

    # Add small delay to all subtitles (0.2 seconds)
    offset = 0.2
    segments.each do |segment|
      segment.start_time += offset  # Push start time forward
      segment.end_time += offset    # Push end time forward
    end

    # Write each segment to SRT file
    segments.each_with_index do |segment, index|
      srt_file.write "#{index + 1}\n"  # Subtitle number (1, 2, 3...)
      # Time range in SRT format (HH:MM:SS,mmm --> HH:MM:SS,mmm)
      srt_file.write "#{format_time(segment.start_time)} --> #{format_time(segment.end_time)}\n"
      srt_file.write "#{segment.text.strip}\n\n"  # Subtitle text with blank line
    end

    # Close file and return path
    srt_file.close
    srt_file.path
  end

  # Convert seconds to SRT time format (HH:MM:SS,mmm)
  def format_time(seconds)
    ms = ((seconds % 1) * 1000).round      # Get milliseconds part
    t = Time.at(seconds).utc.strftime("%H:%M:%S")  # Get hours:minutes:seconds
    "#{t},#{ms.to_s.rjust(3, '0')}"       # Combine with comma separator
  end

  # Main FFmpeg operation - burn subtitles into video
  def burn_subtitles_optimized(input_path, srt_path, original_size_gb)
    # Create unique output filename
    output_path = Rails.root.join("tmp", "video_cache", "burned_#{@recording.id}_#{Time.now.to_i}.mp4").to_s
    FileUtils.mkdir_p(File.dirname(output_path))  # Create directory if needed

    # Choose compression level based on file size
    # Bigger files need more compression to stay under AWS 5GB limit
    crf = calculate_crf_for_size(original_size_gb)
    
    Rails.logger.info "[SubtitleGeneration] Using CRF #{crf} for #{original_size_gb.round(2)}GB input"

    # Build FFmpeg command
    cmd = [
      "ffmpeg",                    # The FFmpeg program itself
      "-y",                        # Overwrite output file without asking (yes to all)
      "-i", input_path,            # Input file path
      
      # Use filter_complex with exact timing control
      "-filter_complex",           # Advanced filtering system (vs simple -vf)
      "[0:v]subtitles=#{srt_path}:force_style='FontName=Arial,FontSize=24,PrimaryColour=&Hffffff,OutlineColour=&H000000,Outline=2'[v]",
      # [0:v] = take video from input 0
      # subtitles= burn in the SRT file
      # force_style= override SRT styling with custom look
      # FontName=Arial = use Arial font
      # FontSize=24 = 24pt font size  
      # PrimaryColour=&Hffffff = white text (&H prefix = hex color in BGR format)
      # OutlineColour=&H000000 = black outline
      # Outline=2 = 2 pixel thick outline
      # [v] = output this filtered video as stream "v"
      
      "-map", "[v]",               # Use the filtered video stream "v" as output video
      "-map", "0:a",               # Use original audio from input 0 (no filtering)
      
      "-c:v", "libx264",           # Video codec: H.264 (most compatible)
      "-crf", crf.to_s,            # Constant Rate Factor: quality level (18=high, 28=medium, 35=low)
      "-preset", "medium",         # Encoding speed vs compression efficiency (ultrafast→veryslow)
      "-profile:v", "high",        # H.264 profile: high = best features/compression
      "-level", "4.0",             # H.264 level: 4.0 = supports 1080p at reasonable bitrates
      "-threads", "12",            # Use 12 CPU threads for encoding (faster on multi-core)
      
      "-c:a", "aac",               # Audio codec: AAC (widely supported)
      "-b:a", "96k",               # Audio bitrate: 96 kilobits/sec (good quality, small size)
      
      "-movflags", "+faststart",   # Move metadata to start of file (web streaming friendly)
      "-max_muxing_queue_size", "4096",  # Buffer size for A/V sync (prevents dropped frames)
      "-pix_fmt", "yuv420p",       # Pixel format: 4:2:0 chroma subsampling (universal compatibility)
      
      output_path                  # Where to save the final video
    ]

    Rails.logger.debug "[SubtitleGeneration] Running FFmpeg:\n#{cmd.join(' ')}"

    # Run FFmpeg with 10 hour timeout
    Timeout::timeout(36000) do 
      stdout, stderr, status = Open3.capture3(*cmd)  # Run command and capture output
      unless status.success?
        Rails.logger.error "[SubtitleGeneration] FFmpeg failed: #{stderr}"
        raise "FFmpeg failed: #{stderr}"
      end
    end

    # Make sure output file exists and isn't tiny
    unless File.exist?(output_path) && File.size(output_path) > 1000000
      raise "FFmpeg output missing or too small"
    end

    # Check if file is too big for AWS (5GB limit)
    output_size_gb = File.size(output_path) / 1.gigabyte.to_f
    Rails.logger.info "[SubtitleGeneration] Initial FFmpeg output: #{File.size(output_path) / 1.megabyte}MB (#{output_size_gb.round(2)}GB)"
    
    # If file is too big, compress it more aggressively
    if output_size_gb >= 4.5  # Conservative limit to ensure we stay under 5GB
      Rails.logger.warn "[SubtitleGeneration] File too large (#{output_size_gb.round(2)}GB), running emergency compression..."
      output_path = emergency_compress(output_path)
      
      # Check final size after emergency compression
      final_size_gb = File.size(output_path) / 1.gigabyte.to_f
      Rails.logger.info "[SubtitleGeneration] Final output after compression: #{File.size(output_path) / 1.megabyte}MB (#{final_size_gb.round(2)}GB)"
      
      # If still too big, give up
      if final_size_gb >= 4.8
        raise "File still too large for AWS after compression: #{final_size_gb.round(2)}GB"
      end
    end
    
    output_path  # Return path to final video
  rescue Timeout::Error
    raise "FFmpeg timed out after 10 hours"
  end

  # Choose compression level based on original file size
  def calculate_crf_for_size(original_size_gb)
    # CRF scale: lower number = better quality, higher number = smaller file
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

  # Last resort compression if file is still too big
  def emergency_compress(input_path)
    emergency_output = "#{input_path}.emergency"  # Temp filename
    
    Rails.logger.info "[SubtitleGeneration] Starting emergency compression..."
    
    # Very aggressive compression settings
    emergency_cmd = [
      "ffmpeg", "-y",        # Overwrite without asking
      "-i", input_path,      # Input file
      "-c:v", "libx264",     # H.264 video
      "-crf", "32",          # High compression (lower quality)
      "-preset", "slow",     # Better compression efficiency
      "-profile:v", "main",  # Good compatibility
      "-level", "4.0",       # H.264 level
      "-c:a", "aac",         # AAC audio
      "-b:a", "64k",         # Very low audio bitrate
      "-movflags", "+faststart",  # Web optimization
      "-pix_fmt", "yuv420p", # Pixel format
      emergency_output       # Output file
    ]
    
    Rails.logger.debug "[SubtitleGeneration] Emergency compression command: #{emergency_cmd.join(' ')}"
    
    begin
      # Run emergency compression
      stdout, stderr, status = Open3.capture3(*emergency_cmd)
      unless status.success?
        Rails.logger.error "[SubtitleGeneration] Emergency compression failed: #{stderr}"
        raise "Emergency compression failed: #{stderr}"
      end
      
      # Check if emergency output exists and isn't tiny
      unless File.exist?(emergency_output) && File.size(emergency_output) > 1000000
        raise "Emergency compression output missing or too small"
      end
      
      # Check final size
      final_size_gb = File.size(emergency_output) / 1.gigabyte.to_f
      Rails.logger.info "[SubtitleGeneration] Emergency compression result: #{final_size_gb.round(2)}GB"
      
      if final_size_gb < 4.8  # Success - file is small enough
        File.delete(input_path)                        # Delete original
        File.rename(emergency_output, input_path)      # Replace with compressed version
        Rails.logger.info "[SubtitleGeneration] ✅ Emergency compression successful: #{final_size_gb.round(2)}GB"
        return input_path
      else
        # Even emergency compression failed
        File.delete(emergency_output) if File.exist?(emergency_output)  # Clean up
        Rails.logger.error "[SubtitleGeneration] ❌ Even emergency compression failed: #{final_size_gb.round(2)}GB"
        raise "File too large even after emergency compression: #{final_size_gb.round(2)}GB"
      end
      
    rescue => e
      # Clean up temp file if something went wrong
      File.delete(emergency_output) if File.exist?(emergency_output)
      raise e
    end
  end

  # Replace original video with subtitled version
  def replace_video_safely(output_path)
    Rails.logger.debug "[SubtitleGeneration] Starting SAFE video replacement..."
    
    # Make sure output file exists and has content
    unless File.exist?(output_path) && File.size(output_path) > 0
      raise "Output file is missing or empty: #{output_path}"
    end
    
    # Final size check before uploading to AWS
    final_size_gb = File.size(output_path) / 1.gigabyte.to_f
    if final_size_gb >= 4.9
      raise "Final file too large for AWS: #{final_size_gb.round(2)}GB"
    end
    
    Rails.logger.info "[SubtitleGeneration] Uploading subtitled video (#{File.size(output_path) / 1.megabyte}MB)..."
    
    # Upload new video to replace old one
    begin
      @recording.video.attach(
        io: File.open(output_path, "rb"),  # Open file for reading
        filename: "subtitled_#{@recording.title.parameterize}_#{@recording.id}.mp4",  # New filename
        content_type: "video/mp4"          # MIME type
      )
      
      # Reload record and verify new video is attached
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

  # Delete temporary files to free up disk space
  def cleanup_temp_files(*paths)
    paths.compact.each do |path|  # Skip nil paths
      if File.exist?(path)
        File.delete(path)
        Rails.logger.debug "[SubtitleGeneration] Cleaned up: #{path}"
      end
    end
  end

  # Return success result
  def success
    Result.new(success?: true)
  end

  # Return failure result with error message
  def failure(msg)
    Result.new(success?: false, error: msg)
  end
end