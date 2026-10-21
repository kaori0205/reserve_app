require 'rails_helper'

# 予約システムチャレンジ Lv4：キャンセル・料金・集計
# このテストがすべて通るように、Reservation・User・Room にメソッドを追加してください。
# テストのファイルは書き換えないでください。

RSpec.describe 'Lv4 キャンセル・料金・集計' do
  include ActiveSupport::Testing::TimeHelpers

  # 「今」を 2030年1月7日（月）8:00 に固定して確かめます
  around do |example|
    travel_to(Time.zone.local(2030, 1, 7, 8, 0)) { example.run }
  end

  let(:room) { Room.create!(name: '会議室A', capacity: 6, price_per_30min: 500) }
  let(:user) { User.create!(name: '山田', email: 'yamada@example.com') }

  def at(hour, min = 0, day: 8)
    Time.zone.local(2030, 1, day, hour, min)
  end

  def reserve(start_at, end_at, room: self.room, user: self.user)
    Reservation.create!(room: room, user: user, start_at: start_at, end_at: end_at, people: 2)
  end

  # 過去の予約は作れないので、ルールを通さずに保存します
  def reserve_without_rules(start_at, end_at, room: self.room, user: self.user)
    r = Reservation.new(room: room, user: user, start_at: start_at, end_at: end_at, people: 2)
    r.save!(validate: false)
    r
  end

  describe 'キャンセル' do
    it 'Reservation#cancel! で、状態がキャンセル済みになり true を返す' do
      reservation = reserve(at(10), at(11))
      expect(reservation.cancel!).to eq true
      expect(reservation.reload).to be_cancelled
    end

    it 'キャンセルは利用日の前日まで。当日はキャンセルできず false を返す' do
      reservation = reserve(at(10, day: 7), at(11, day: 7))
      expect(reservation.cancel!).to eq false
      expect(reservation.reload).to be_reserved
      expect(reservation.errors[:base]).to be_present
    end

    it 'すでにキャンセル済みの予約は、もう一度キャンセルできない' do
      reservation = reserve(at(10), at(11))
      reservation.cancel!
      expect(reservation.cancel!).to eq false
    end

    it 'Reservation#cancellable? で、キャンセルできるかどうかが分かる' do
      expect(reserve(at(10), at(11)).cancellable?).to eq true
      expect(reserve(at(10, day: 7), at(11, day: 7)).cancellable?).to eq false
    end

    it '23:59 までは前日あつかい（日付で判断する）' do
      reservation = reserve(at(9), at(10))
      travel_to(Time.zone.local(2030, 1, 7, 23, 59)) # 前日の23:59へ進める
      expect(reservation.cancellable?).to eq true
    end
  end

  describe 'Reservation#price（料金）' do
    it '平日の昼は「30分あたりの料金 × 30分の数」' do
      # 1月8日（火）10:00〜11:30 → 500円 × 3 = 1500円
      expect(reserve(at(10), at(11, 30)).price).to eq 1500
    end

    it '18:00 以降に始まる30分は、夜間料金で1.25倍' do
      # 17:00〜19:00 → 500 × 2（昼） + 625 × 2（夜） = 2250円
      expect(reserve(at(17), at(19)).price).to eq 2250
    end

    it '土曜・日曜は、すべての時間が1.5倍' do
      # 1月12日（土）10:00〜11:00 → 750 × 2 = 1500円
      expect(reserve(at(10, day: 12), at(11, day: 12)).price).to eq 1500
      # 1月13日（日）10:00〜10:30 → 750円
      expect(reserve(at(10, day: 13), at(10, 30, day: 13)).price).to eq 750
    end

    it '土日の夜は、1.5倍のうえに1.25倍' do
      # 1月12日（土）18:00〜19:00 → 500 × 1.5 × 1.25 = 937.5 が2つ → 1875円
      expect(reserve(at(18, day: 12), at(19, day: 12)).price).to eq 1875
    end

    it '合計の1円未満は切り捨てる' do
      cheap = Room.create!(name: '会議室C', capacity: 4, price_per_30min: 333)
      # 18:00〜18:30 → 333 × 1.25 = 416.25 → 416円
      expect(reserve(at(18), at(18, 30), room: cheap).price).to eq 416
    end
  end

  describe 'User#upcoming_reservations（これからの予約）' do
    let!(:past)      { reserve_without_rules(at(10, day: 6), at(11, day: 6)) }
    let!(:later)     { reserve(at(15, day: 9), at(16, day: 9)) }
    let!(:sooner)    { reserve(at(10), at(11)) }
    let!(:cancelled) { reserve(at(13), at(14)).tap(&:cancel!) }
    let!(:others)    { reserve(at(17), at(18), user: User.create!(name: '佐藤', email: 'sato@example.com')) }

    it '自分の、まだ始まっていない予約中の予約だけを返す' do
      expect(user.upcoming_reservations).to contain_exactly(sooner, later)
    end

    it '開始が早い順に並ぶ' do
      expect(user.upcoming_reservations.to_a).to eq [sooner, later]
    end
  end

  describe 'Room#occupancy_rate(year, month)（月の稼働率）' do
    # 稼働率(%) = その月に始まる予約中の予約の合計時間（分） ÷ （その月の日数 × 720分） × 100
    # 720分 = 営業時間 9:00〜21:00 の12時間。小数第1位までに四捨五入します
    it '予約がなければ 0.0' do
      expect(room.occupancy_rate(2030, 1)).to eq 0.0
    end

    it 'その月の予約の時間から計算する' do
      reserve(at(9), at(13))                    # 240分
      reserve(at(13, day: 10), at(17, day: 10)) # 240分
      # 480 ÷ (31 × 720) × 100 = 2.150… → 2.2
      expect(room.occupancy_rate(2030, 1)).to eq 2.2
    end

    it 'キャンセル済みの予約と、ほかの月の予約は数えない' do
      reserve(at(9), at(13))                            # 240分（数える）
      reserve(at(13), at(17)).cancel!                   # キャンセル済み
      reserve(Time.zone.local(2030, 2, 1, 9, 0), Time.zone.local(2030, 2, 1, 13, 0)) # 2月
      # 240 ÷ (31 × 720) × 100 = 1.075… → 1.1
      expect(room.occupancy_rate(2030, 1)).to eq 1.1
    end
  end

  describe 'Reservation.on(date)（その日の予約）' do
    it '指定した日に始まる予約を、開始が早い順に返す' do
      second = reserve(at(13), at(14))
      first  = reserve(at(9), at(10))
      reserve(at(9, day: 9), at(10, day: 9))
      expect(Reservation.on(Date.new(2030, 1, 8)).to_a).to eq [first, second]
    end
  end
end