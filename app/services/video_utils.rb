
module VideoUtils
    def download_video
        temp_file = Tempfile.new(['recording', '.mp4'])
    
        @recording.video.open do |file|
          FileUtils.cp(file.path, temp_file.path)
        end
    
        FileUtils.chmod(0644, temp_file.path)
        temp_file.path
      end
    end


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
  