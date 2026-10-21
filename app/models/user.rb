class User < ApplicationRecord
    validates :name, presence: true
    validates :email, presence: true, uniqueness: true

    has_many :reservations, dependent: :destroy

    def upcoming_reservations
       reservations.reserved.where('start_at > ?', Time.current) .order(:start_at)
    end
end
