class Room < ApplicationRecord
    validates :name, presence: true, uniqueness: true
    validates :capacity, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
    validates :price_per_30min, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }   

    has_many :reservations, dependent: :destroy
    
    def occupancy_rate(year, month)
        return 0.0 if year.blank? || month.blank?
        first_day = Date.new(year, month, 1)
        total_minutes = reservations.reserved.where(start_at: first_day.in_time_zone.all_month).sum { |r| ((r.end_at - r.start_at) / 60).to_i }
        how_many_days = first_day.end_of_month.day

        occupancy_rate = (total_minutes * 100.0 / (how_many_days * 720)).round(1)

    end

    # available_between はクラスメソッドなので private の上に置くのが一般的です
    def self.available_between(start_at, end_at, people: 1)
        return if start_at.blank? || end_at.blank?
        busy_rooms = Reservation.reserved.overlapping(start_at, end_at)
        where(capacity: people..).where.not(id: busy_rooms.select(:room_id))
    end

    # free_slots はインスタンスメソッド（外から呼ぶので private の外に出す）
    def free_slots(date)
        return [] if date.blank?

        start_time = date.in_time_zone.change(hour: 9)
        end_time = date.in_time_zone.change(hour: 21)
        slots = []
        
        current_time = start_time

        while current_time < end_time
            slot_end = current_time + 30.minutes

            # 1. Room自身の reservations から、予約中で、かつその30分に重なるものがないか（none?）調べる
            is_free = reservations.reserved.overlapping(current_time, slot_end).none?
    
            if is_free
                slots << [current_time, slot_end]
            end

            # 2. 次の30分に進めるために slot_end を代入する
            current_time = slot_end
        end

        slots
    end
end