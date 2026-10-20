class Reservation < ApplicationRecord
    belongs_to :user
    belongs_to :room
    
    validates :room, presence: true
    validates :user, presence: true
    validates :people, presence: true
    validates :start_at, presence: true
    validates :end_at, presence: true
    validates :status, presence: true
    
    enum :status, { reserved: 0, cancelled: 1 }

end
