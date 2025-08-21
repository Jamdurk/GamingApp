class Recording < ApplicationRecord
    has_one_attached :video
    has_many :clips,     dependent: :destroy
    has_one  :transcript, dependent: :destroy
    has_many :segments, through: :transcript
    # Video upload validations
    validates :video, attached:         true
    validates :video, duration:       { greater_than: 15.minutes }
    validates :video, content_type:   ["video/mp4"]
    validates :video, processable_file: true
    validates :video, dimension:      {
                                       width:  { min: 1920, max: 3840 },
                                       height: { min: 1080, max: 2160 }
      }

    validates :title,     presence: true,  length: { maximum: 25 }, uniqueness: true
    validates :game_name, presence: true,  length: { maximum: 25 }
    validates :players,   presence: true,  length: { maximum: 50 } 
    validate  :video_must_be_processable
    validates :video, size:{ less_than: 5.gigabytes, message: 'must be less than 5GB. For larger files, please compress them first using Handbrake or similar tools.' }, if: -> { Rails.env.production? }
    validate  :no_potato_in_title


    def show_processing_section?
      transcript.nil? || transcript.created_at >= 3.hours.ago
    end
    
    def processing_message
      if transcript.nil?
        "Transcription in progress... please check back shortly."
      elsif video.filename.to_s.include?("subtitled")
        "✅ Subtitled recording ready!"
      else
        "Subtitles are being burned into the video... please check back shortly."
      end
    end
    

    def video_must_be_processable
      return unless video.attached?
      
      # For direct uploads, the file might not be analyzed yet
      if video.blob.metadata.blank?
        # Queue analysis if it hasn't happened yet
        video.analyze_later unless video.analyzed?
      end
    end

    def no_potato_in_title
      forbidden_words = ["potato", "potatos", "potato's", "Potato", "Potatos", "Potato's", "Potato's", 
                         "POTATO", "POTATOS", "POTATO'S", "Baked Potato"]
      forbidden_words.each do |word| 
        if title.present? && title.include?(word)
          errors.add(:title, "can't be potato....Are you stupid cunt? You and i both that the word potato has no place in a title,
                            & the very idea of a potato in a title is just plain stupid & is an insult to genuinly everything.
                            Prick.")
          break
        end
      end
    end

end