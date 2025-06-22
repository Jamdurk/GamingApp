require "tempfile"
require "open3"

class ClipGenerationService
 def self.call(recording:, start_time:, end_time:, title:, clip: nil)
   new(recording, start_time, end_time, title, clip).call
 end

 def initialize(recording, start_time, end_time, title, existing_clip = nil)
   @recording  = recording
   @start_time = start_time
   @end_time   = end_time
   @title      = title
   @clip       = existing_clip
 end

 def call
   # Guard-rail validations
   return failure("Recording must be present to make clip") if @recording.nil?
   return failure("Start time cannot be empty") if @start_time.blank?
   return failure("End time cannot be empty") if @end_time.blank?

   # Convert timestamps to seconds
   start_sec = timestamp_to_seconds(@start_time)
   end_sec   = timestamp_to_seconds(@end_time)
   duration  = end_sec - start_sec

   # Basic time validation
   return failure("End time must be after start time") if end_sec <= start_sec
   return failure("Clip duration must be between 1 second and 5 minutes") if duration < 1 || duration > 300

   # Handle different storage services
   if Rails.env.test? || @recording.video.service.name == :test
     # In test environment, use local file path
     @recording.video.open do |file|
       input_source = file.path
       
       # Create output path
       output_path = temp_output_path

       # Build FFmpeg command for high-quality clip extraction
       cmd = build_ffmpeg_command(input_source, start_sec, duration, output_path)
       
       Rails.logger.info "[ClipGeneration] Starting FFmpeg for #{@recording.id} (#{start_sec}s - #{end_sec}s)"
       
       # Execute FFmpeg with timeout protection
       stdout, stderr, status = nil
       begin
         Timeout::timeout(300) do  # 5 minute timeout for clip generation
           stdout, stderr, status = Open3.capture3(*cmd)
         end
       rescue Timeout::Error
         return failure("Clip generation timed out after 5 minutes")
       end
       
       unless status&.success?
         Rails.logger.error "[ClipGeneration] FFmpeg failed: #{stderr}"
         return failure("Video processing failed: #{stderr&.lines&.last}")
       end
       
       # Verify output file exists and has content
       unless File.exist?(output_path) && File.size(output_path) > 0
         return failure("Failed to generate clip file")
       end
       
       # Create or update clip record
       clip = @clip || @recording.clips.build
       clip.assign_attributes(
         title:      @title,
         start_time: start_sec.to_i,
         end_time:   end_sec.to_i
       )
       
       # Attach the clip video
       clip.video.attach(
         io:           File.open(output_path, "rb"),
         filename:     "#{@recording.title.parameterize}_clip_#{Time.current.to_i}.mp4",
         content_type: "video/mp4"
       )
       
       # Save and return result
       if clip.save
         Rails.logger.info "[ClipGeneration] Successfully created clip #{clip.id}"
         return success(clip)
       else
         return failure(clip.errors.full_messages.join(", "))
       end
     end
   else
     # Production: use S3 URL
     input_source = @recording.video.url(expires_in: 7200)
     
     # Create output path
     output_path = temp_output_path

     # Build FFmpeg command for high-quality clip extraction
     cmd = build_ffmpeg_command(input_source, start_sec, duration, output_path)
     
     Rails.logger.info "[ClipGeneration] Starting FFmpeg for #{@recording.id} (#{start_sec}s - #{end_sec}s)"
     
     # Execute FFmpeg with timeout protection
     stdout, stderr, status = nil
     begin
       Timeout::timeout(300) do  # 5 minute timeout for clip generation
         stdout, stderr, status = Open3.capture3(*cmd)
       end
     rescue Timeout::Error
       return failure("Clip generation timed out after 5 minutes")
     end
     
     unless status&.success?
       Rails.logger.error "[ClipGeneration] FFmpeg failed: #{stderr}"
       return failure("Video processing failed: #{stderr&.lines&.last}")
     end
     
     # Verify output file exists and has content
     unless File.exist?(output_path) && File.size(output_path) > 0
       return failure("Failed to generate clip file")
     end
     
     # Create or update clip record
     clip = @clip || @recording.clips.build
     clip.assign_attributes(
       title:      @title,
       start_time: start_sec.to_i,
       end_time:   end_sec.to_i
     )
     
     # Attach the clip video
     clip.video.attach(
       io:           File.open(output_path, "rb"),
       filename:     "#{@recording.title.parameterize}_clip_#{Time.current.to_i}.mp4",
       content_type: "video/mp4"
     )
     
     # Save and return result
     if clip.save
       Rails.logger.info "[ClipGeneration] Successfully created clip #{clip.id}"
       return success(clip)
     else
       return failure(clip.errors.full_messages.join(", "))
     end
   end
   
 rescue StandardError => e
   Rails.logger.error "[ClipGeneration] Unexpected error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
   failure("An unexpected error occurred: #{e.message}")
   
 ensure
   # Clean up temp file
   if output_path && File.exist?(output_path)
     File.delete(output_path) 
     Rails.logger.debug "[ClipGeneration] Cleaned up temp file: #{output_path}"
   end
 end

 private

 def build_ffmpeg_command(input_source, start_sec, duration, output_path)
   [
     "ffmpeg",
     "-ss", start_sec.to_s,              # Seek before input 
     "-i", input_source,                 # Input from file path or S3 URL
     "-t", duration.to_s,                # Duration to extract
     
     # Video encoding settings for quality preservation
     "-c:v", "libx264",                  # H.264 codec
     "-preset", "slow",                  # Better compression (worth it for gaming footage)
     "-crf", "18",                       # High quality (18 is visually lossless)
     "-pix_fmt", "yuv420p",              # Compatibility
     "-profile:v", "high",               # H.264 high profile
     "-level", "4.1",                    # Compatibility level
     
     # Audio settings
     "-c:a", "aac",                      # AAC audio
     "-b:a", "320k",                     # High quality audio
     "-ar", "48000",                     # Sample rate
     
     # Output optimization
     "-movflags", "+faststart",          # Web optimization
     "-max_muxing_queue_size", "9999",   # Prevent packet loss
     "-avoid_negative_ts", "make_zero",  # Fix timestamp issues
     
     # Overwrite and suppress verbose output
     "-y",                               # Overwrite output
     "-loglevel", "warning",             # Only show warnings/errors
     "-stats",                           # Show progress stats
     
     output_path
   ]
 end

 def timestamp_to_seconds(ts)
   # Handle both HH:MM:SS and MM:SS formats
   parts = ts.strip.split(":").map(&:to_f)
   
   case parts.length
   when 3  # HH:MM:SS
     (parts[0] * 3600) + (parts[1] * 60) + parts[2]
   when 2  # MM:SS
     (parts[0] * 60) + parts[1]
   else
     raise ArgumentError, "Invalid timestamp format: #{ts}"
   end
 end

 def temp_output_path
   # Create temp file in system temp directory
   Dir::Tmpname.create(['clip_', '.mp4']) { |path| path }
 end

 # Result object for consistent returns
 Result = Struct.new(:success?, :clip, :error, keyword_init: true)

 def success(clip)
   Result.new(success?: true, clip: clip)
 end

 def failure(error_message)
   Result.new(success?: false, error: error_message)
 end
end