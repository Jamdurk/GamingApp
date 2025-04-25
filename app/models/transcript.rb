class Transcript < ApplicationRecord
  belongs_to :recording
  has_many :segments, dependent: :destroy
  
  validates :data, presence: true
  
end
