class Segment < ApplicationRecord
  belongs_to :transcript


  validates :start_time, :end_time, :text, presence: true 
end
