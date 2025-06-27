module VideoUtils
  def download_video
    output_dir = if Rails.env.production?
                   "/video_storage"  # Existing production path (volume 40gb attached to sidekiq machine on fly.io)
                 else
                   Rails.root.join("tmp", "video_storage").to_s  # Dev env path for uploading locally
                 end
    
    FileUtils.mkdir_p(output_dir)
  
    temp_path = File.join(output_dir, "original_#{@recording.id}_#{Time.now.to_i}.mp4")
  
    @recording.video.open do |file|
      FileUtils.cp(file.path, temp_path)
      FileUtils.chmod(0644, temp_path)
    end

    temp_path  # Return the temp_path
  end  # This end was missing!

  def deduplicate_segments(segments, max_repetitions=3) # Was originally using this in my transcription service, but removed due to some conflicts. Storing here in case for future use.
    result = []
    current_text = nil
    repetition_count = 0
    
    segments.each do |segment|
      if segment[:text] == current_text
        repetition_count += 1
        # Skip if we've seen this text too many times in a row
        next if repetition_count > max_repetitions
      else
        current_text = segment[:text]
        repetition_count = 1
      end
      
      result << segment
    end
    
    result
  end
end