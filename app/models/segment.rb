class Segment < ApplicationRecord
  belongs_to :transcript


  validates :start_time, :end_time, :text, presence: true 
  validate :start_must_be_before_end

  private

  def start_must_be_before_end
    if start_time.present? && end_time.present? && start_time > end_time
      errors.add(:start_time, "must not be after end time")
    end
  end
end
