class Clip < ApplicationRecord
  belongs_to :recording

  validates :video, attached: true
  validates :video, attached:         true 
  validates :video, duration:       { between: 1.second..5.minutes }
  validates :video, content_type:   ["video/mp4"]
  validates :video, processable_file: true
  validates :video, dimension:      {
                                     width:  { min: 1920, max: 3840 },
                                     height: { min: 1080, max: 2160 }
    }
end
