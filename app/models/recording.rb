class Recording < ApplicationRecord
    has_one_attached :video
    has_many :clips dependant: :destroy
end
