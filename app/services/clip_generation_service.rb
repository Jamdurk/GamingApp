# Load Ruby’s std‑lib helper for creating throw‑away files.
require "tempfile"

class ClipGenerationService
  def self.call(recording:, start_time:, end_time:, title:)
    new(recording, start_time, end_time, title).call
  end

  # Save incoming arguments into ivars so instance methods can use them.
  def initialize(recording, start_time, end_time, title)
    @recording  = recording   # ActiveRecord::Recording
    @start_time = start_time  # "HH:MM:SS" string
    @end_time   = end_time    # "HH:MM:SS" string
    @title      = title       # String for the clip’s title
  end

  # ──────────────────────────────────────────
  # MAIN WORKFLOW
  # ──────────────────────────────────────────
  def call
    # Guard-rail validations
    if @recording.nil?
      return Result.new(success?: false, error: "Recording must be present to make clip")
    end

    if @start_time.nil? || @start_time.empty?
      return Result.new(success?: false, error: "Start time cannot be empty")
    end

    if @end_time.nil? || @end_time.empty?
      return Result.new(success?: false, error: "End time cannot be empty")
    end

    # 1.  Get a real file‑system path to the attached video blob.
    video_path = ActiveStorage::Blob
                   .service
                   .send(:path_for, @recording.video.key)

    # 2.  Wrap that file with Streamio so we can query metadata & transcode.
    movie = FFMPEG::Movie.new(video_path)

    # 3.  Convert "HH:MM:SS" into integer seconds.
    start_sec = timestamp_to_seconds(@start_time)
    end_sec   = timestamp_to_seconds(@end_time)

    # 4.  Guard‑rail validations.
    if end_sec <= start_sec
      return Result.new(success?: false,
                        error:   "End time must be after start")
    elsif end_sec > movie.duration
      return Result.new(success?: false,
                        error:   "End time exceeds recording duration")
    end

    if @start_time.nil? || @start_time.empty?
      return Result.new(success?: false, error: "Start time cannot be empty")
    end

    if @end_time.nil? || @end_time.empty?
      return Result.new(success?: false, error: "End time cannot be empty")
    end

    # 5.  Pick a unique temp path for FFmpeg’s output slice.
    output_path = temp_output_path

    # 6.  Ask FFmpeg to copy‑slice the segment:
    #     -ss : seek to start
    #     -to : absolute end
    #     -c  copy : no re‑encode → very fast
    movie.transcode(output_path,
                    %W[-ss #{start_sec} -to #{end_sec} -c copy])

    # 7.  Build a new Clip associated to @recording.
    clip = @recording.clips.build(
      title:      @title,
      start_time: start_sec,
      end_time:   end_sec
    )

    # 8.  Attach the freshly sliced file.
    clip.video.attach(
      io:           File.open(output_path, "rb"),   # reopen in binary mode
      filename:     File.basename(output_path),
      content_type: "video/mp4"
    )

    # 9.  Persist! (`save!` will raise if validations fail)
    clip.save!

    # 10. Return a success Result carrying the clip.
    success(clip)

  rescue => e
    # Catch anything (FFmpeg error, validation error, etc.).
    failure(e.message)

  ensure
    # 11. House‑keeping: delete the temp file if it still exists.
    File.delete(output_path) if output_path && File.exist?(output_path)
  end

  # ──────────────────────────────────────────
  # PRIVATE HELPERS
  # ──────────────────────────────────────────
  private

  # Convert "HH:MM:SS" → seconds.
  def timestamp_to_seconds(ts)
    parts = ts.split(":")                                # Split timestamp "00:00:05.5" into array ["00","00","05.5"]
    parts[2] = parts[2].to_f                             # Convert seconds part to float to preserve decimals (5.5)
    parts.map.with_index { |v, idx| idx == 2 ? v : v.to_i } # Convert hours and minutes to integers, keep seconds as float
         .reverse                                        # Reverse to [5.5, 0, 0] (seconds, minutes, hours)
         .each_with_index                                # Create pairs with indices: [[5.5,0], [0,1], [0,2]]
         .sum { |v, idx| v * 60**idx }                   # Calculate: 5.5*60⁰ + 0*60¹ + 0*60² = 5.5 seconds
  end

  # Create an empty /tmp/clip_XXXX.mp4 and return its path.
  def temp_output_path
    tempfile = Tempfile.new(["clip_", ".mp4"], binmode: true)
    tempfile.path  # string path for FFmpeg
  ensure
    tempfile.close # close handle; file stays until we delete it above
  end

  # Sugar helpers to wrap Result creation.
  Result = Struct.new(:success?, :clip, :error, keyword_init: true)

  def success(clip) = Result.new(success?: true,  clip: clip)
  def failure(msg)  = Result.new(success?: false, error: msg)
end
