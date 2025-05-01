
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
  