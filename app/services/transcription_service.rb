require "open3"
require "fileutils"

class TranscriptionService
    def self.call(recording:)
        new(recording).call
    end

    def initialize(recording)
        @recording = recording
    end

    def call 
        input_path = download_video
        json_path = run_whisper(input_path)
        parse_transcript(json_path)
    end

    private 

    def download_video
        temp_file = Tempfile.new(['recording', '.mp4'])
        
        @recording.video.open do |file|
            # Create a persistent copy of the file
            FileUtils.cp(file.path, temp_file.path)
        end
        
        # Make sure the file has correct permissions
        FileUtils.chmod(0644, temp_file.path)
        
        # Return the path but don't close the tempfile yet
        temp_file.path
    end

    def run_whisper(input_path)
        base_name = File.basename(input_path, File.extname(input_path))
        output_dir = "/tmp"
        
        # Verify file exists and is readable
        unless File.exist?(input_path) && File.readable?(input_path)
            raise "Input file does not exist or is not readable: #{input_path}"
        end
        
        cmd = [
            "whisper",
            input_path,
            "--model", "medium",
            "--output_dir", output_dir,
            "--output_format", "json",
            "--device", "cpu"
        ]

        stdout, stderr, status = Open3.capture3(*cmd)

        unless status.success?
            raise "Whisper failed: #{stderr}"
        end
        
        # Look for likely output names
        potential_paths = [
            "#{output_dir}/#{base_name}.json",
            "#{output_dir}/#{File.basename(input_path)}.json",
            "#{output_dir}/#{base_name}.transcription.json"
        ]
        
        json_path = potential_paths.find { |path| File.exist?(path) }
        
        # If none of the expected paths exist, look for any recently created JSON
        unless json_path
            json_files = Dir.glob("#{output_dir}/*.json").select do |f|
                File.mtime(f) > (Time.now - 60) # Files modified in the last minute
            end
            
            json_path = json_files.max_by { |f| File.mtime(f) } if json_files.any?
        end
        
        # Still no file found
        unless json_path && File.exist?(json_path)
            raise "Whisper JSON output not found"
        end
        
        json_path
    end

    def parse_transcript(json_path)
        raw      = File.read(json_path)
        data     = JSON.parse(raw)
        segments = data.fetch("segments", [])
      
        # 1) Make sure a Transcript exists
        transcript = @recording.transcript ||
                     @recording.create_transcript!(data: data)
      
        # (Optional) clear out old segments if re-running
        transcript.segments.destroy_all
      
        # 2) Create one Segment per whisper chunk
        segments.each do |seg|
          next if seg["text"].blank?
          transcript.segments.create!(
            start_time: seg["start"],
            end_time:   seg["end"],
            text:       seg["text"]
          )
        end
      end      
end