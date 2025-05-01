class Recording < ApplicationRecord
    has_one_attached :video
    has_many :clips,     dependent: :destroy
    has_one  :transcript, dependent: :destroy
    has_many :segments, through: :transcript
    # Video upload validations
    validates :video, attached:         true 
    validates :video, duration:       { greater_than: 15.minutes }, unless: -> { Rails.env.test? }
    validates :video, content_type:   ["video/mp4"]
    validates :video, processable_file: true
    validates :video, dimension:      {
                                       width:  { min: 1920, max: 3840 },
                                       height: { min: 1080, max: 2160 }
      }

    validates :title,     presence: true,  length: { maximum: 25 }, uniqueness: true
    validates :game_name, presence: true,  length: { maximum: 25 }
    validates :players,   presence: true,  length: { maximum: 50 } # Right now players is a single attribute, and the model here is contraining. Will need to add player model at some point
  
end