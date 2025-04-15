class Clip < ApplicationRecord
  belongs_to :recording
  has_one_attached :video

  validates :video, duration:       { between: 1.second..5.minutes }
  validates :video, content_type:   ["video/mp4"]
  validates :video, processable_file: true
  validates :video, dimension:      {
                                     width:  { min: 1920, max: 3840 },
                                     height: { min: 1080, max: 2160 }
    }


  validates :title,                    presence: true, uniqueness: true, length: { maximum: 30 }
  validates :start_time,               presence: true
  validates :end_time,                 presence: true
  validate  :start_must_be_before_end

  def start_must_be_before_end
    if start_time.present? && end_time.present? && start_time >= end_time
       errors.add(:start_time, "must be before end time")
    end
  end
end
