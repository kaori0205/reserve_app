class Reservation < ApplicationRecord
    belongs_to :user
    belongs_to :room
    
    validates :room, presence: true
    validates :user, presence: true
    validates :people, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
    validates :start_at, presence: true
    validates :end_at, presence: true
    validates :status, presence: true
    enum :status, { reserved: 0, cancelled: 1 }

    validate :people_within_capacity
    validate :end_at_after_start_at
    validate :must_be_on_30_minute_boundary
    validate :must_not_have_seconds
    validate :within_4hours
    validate :within_business_hours
    validate :must_be_on_same_day
    validate :must_be_later_than_now, on: :create

    scope :on, ->(date) { where(start_at: date.all_day).order(:start_at) }
     # 予約の時間が重なるかどうかを判定するスコープ
    scope :overlapping, ->(start_at, end_at) {where.not("start_at >= ? OR end_at <= ?", end_at, start_at)}
   
    validate :overlapping_is_not_allowed, if: :reserved?

    def price
        total = 0
        slot_start = start_at
        
        while slot_start < end_at
          rate = 1

          rate *=1.25 if slot_start.hour >= 18

          rate *=1.5 if slot_start.saturday? || slot_start.sunday?

          total += room.price_per_30min * rate

          slot_start += 30.minutes
        end

        total.floor
    end

    def cancellable?
        reserved? && Time.current.to_date < start_at.to_date
    end

    def cancel!
        unless cancellable?
            errors.add(:base, "予約当日はキャンセルできません")
            return false
        end
        update!(status: :cancelled)
        true
    end

    private

    def overlapping_is_not_allowed
        return if start_at.blank? || end_at.blank? || room.blank?
        overlapping_reservations = Reservation.where(room: room)
                                              .where.not(id: id)
                                              .overlapping(start_at, end_at)
                                              .where(status: :reserved)
        if overlapping_reservations.exists?
            errors.add(:base, "予約が重なっています")
        end
    end

    # 予約の人数が部屋の定員を超えていないことを検証する
    def people_within_capacity
        return if room.blank? || people.blank?
        if people > room.capacity
            errors.add(:people, "は部屋の定員を超えています")
        end
    end

    # 予約の終了時刻が開始時刻より後であることを検証する
    def end_at_after_start_at
        return if start_at.blank? || end_at.blank?
        if end_at <= start_at
            errors.add(:end_at, "は開始時刻より後である必要があります")
        end
    end

    # 予約の開始時刻と終了時刻が30分単位であることを検証する
    def must_be_on_30_minute_boundary
        return if start_at.blank? || end_at.blank?
        if start_at.min % 30 != 0
            errors.add(:start_at, "は30分単位である必要があります")
        end
        if end_at.min % 30 != 0
            errors.add(:end_at, "は30分単位である必要があります")
        end
    end

    # 予約の開始時刻と終了時刻に秒が含まれていないことを検証する
    def must_not_have_seconds
        return if start_at.blank? || end_at.blank?
        if start_at.sec != 0
            errors.add(:start_at, "は秒を含まない必要があります")
        end
        if end_at.sec != 0
            errors.add(:end_at, "は秒を含まない必要があります")
        end
    end

    # 予約の開始時刻と終了時刻が4時間以内であることを検証する
    def within_4hours
        return if start_at.blank? || end_at.blank?
        if end_at - start_at > 4.hours
            errors.add(:end_at, "1回の予約は最長4時間までです")
        end
    end

    # 予約の開始時刻と終了時刻が営業時間内であることを検証する
    def within_business_hours
        return if start_at.blank? || end_at.blank?
        if start_at < start_at.change(hour: 9, min: 0) 
            errors.add(:start_at, "予約は営業時間内（9:00〜21:00）である必要があります")
        end
        if end_at > start_at.change(hour: 21, min: 0)
            errors.add(:end_at, "予約は営業時間内（9:00〜21:00）である必要があります")
        end
    end

    # 予約の開始時刻と終了時刻が同じ日であることを検証する
    def must_be_on_same_day
        return if start_at.blank? || end_at.blank?
        if start_at.to_date != end_at.to_date
            errors.add(:end_at, "予約は日をまたぐことはできません")
        end
    end

    # 予約の開始時刻が現在時刻より後であることを検証する
    def must_be_later_than_now
        return if start_at.blank?
        if start_at < Time.current
            errors.add(:start_at, "は現在時刻より後である必要があります")
        end
    end
end
