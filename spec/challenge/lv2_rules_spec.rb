require 'rails_helper'

# 予約システムチャレンジ Lv2：予約のルール
# このテストがすべて通るように、Reservation にバリデーションを追加してください。
# テストのファイルは書き換えないでください。

RSpec.describe 'Lv2 予約のルール' do
  include ActiveSupport::Testing::TimeHelpers

  # 「今」を 2030年1月7日（月）8:00 に固定して確かめます
  around do |example|
    travel_to(Time.zone.local(2030, 1, 7, 8, 0)) { example.run }
  end

  let(:room) { Room.create!(name: '会議室A', capacity: 6, price_per_30min: 500) }
  let(:user) { User.create!(name: '山田', email: 'yamada@example.com') }

  # 明日（1月8日・火）の 10:00〜11:00・2人 の予約をもとに、一部だけ変えて確かめます
  def build_reservation(start_at: Time.zone.local(2030, 1, 8, 10, 0), end_at: Time.zone.local(2030, 1, 8, 11, 0), people: 2)
    Reservation.new(room: room, user: user, start_at: start_at, end_at: end_at, people: people)
  end

  def at(hour, min = 0, day: 8)
    Time.zone.local(2030, 1, day, hour, min)
  end

  it 'ルールを守った予約は保存できる' do
    expect(build_reservation).to be_valid
  end

  describe '日時' do
    it '開始日時（start_at）は必須' do
      reservation = build_reservation(start_at: nil)
      expect(reservation).not_to be_valid
      expect(reservation.errors[:start_at]).to be_present
    end

    it '終了日時（end_at）は必須' do
      reservation = build_reservation(end_at: nil)
      expect(reservation).not_to be_valid
      expect(reservation.errors[:end_at]).to be_present
    end

    it '終了は開始より後でなければならない' do
      reservation = build_reservation(start_at: at(11), end_at: at(10))
      expect(reservation).not_to be_valid
      expect(reservation.errors[:end_at]).to be_present
    end

    it '開始と終了が同じ時刻の予約はできない' do
      reservation = build_reservation(start_at: at(10), end_at: at(10))
      expect(reservation).not_to be_valid
      expect(reservation.errors[:end_at]).to be_present
    end
  end

  describe '30分単位' do
    it '開始は「00分」か「30分」ちょうどでなければならない' do
      expect(build_reservation(start_at: at(10, 30), end_at: at(11))).to be_valid
      reservation = build_reservation(start_at: at(10, 15), end_at: at(11))
      expect(reservation).not_to be_valid
      expect(reservation.errors[:start_at]).to be_present
    end

    it '終了も「00分」か「30分」ちょうどでなければならない' do
      expect(build_reservation(start_at: at(10), end_at: at(10, 30))).to be_valid
      reservation = build_reservation(start_at: at(10), end_at: at(10, 45))
      expect(reservation).not_to be_valid
      expect(reservation.errors[:end_at]).to be_present
    end

    it '秒が入っている時刻はだめ（10:00:30 など）' do
      reservation = build_reservation(start_at: at(10) + 30.seconds, end_at: at(11))
      expect(reservation).not_to be_valid
      expect(reservation.errors[:start_at]).to be_present
    end

    it '1回の予約は最長4時間まで' do
      expect(build_reservation(start_at: at(10), end_at: at(14))).to be_valid
      reservation = build_reservation(start_at: at(10), end_at: at(14, 30))
      expect(reservation).not_to be_valid
      expect(reservation.errors[:end_at]).to be_present
    end
  end

  describe '営業時間（9:00〜21:00）' do
    it '9:00 からの予約はできる' do
      expect(build_reservation(start_at: at(9), end_at: at(10))).to be_valid
    end

    it '9:00 より前に始まる予約はできない' do
      reservation = build_reservation(start_at: at(8, 30), end_at: at(10))
      expect(reservation).not_to be_valid
      expect(reservation.errors[:start_at]).to be_present
    end

    it '21:00 ちょうどに終わる予約はできる' do
      expect(build_reservation(start_at: at(20), end_at: at(21))).to be_valid
    end

    it '21:00 を過ぎて終わる予約はできない' do
      reservation = build_reservation(start_at: at(20), end_at: at(21, 30))
      expect(reservation).not_to be_valid
      expect(reservation.errors[:end_at]).to be_present
    end

    it '日をまたぐ予約はできない' do
      reservation = build_reservation(start_at: at(20), end_at: at(10, day: 9))
      expect(reservation).not_to be_valid
      expect(reservation.errors[:end_at]).to be_present
    end
  end

  describe '過去の日時' do
    it '開始が今より前の予約は作れない' do
      reservation = build_reservation(start_at: at(7, day: 7), end_at: at(9, day: 7))
      expect(reservation).not_to be_valid
      expect(reservation.errors[:start_at]).to be_present
    end

    it '作った予約は、その時間が過ぎても有効のまま（キャンセルなどで保存し直せる）' do
      reservation = build_reservation
      reservation.save!
      travel_to(Time.zone.local(2030, 1, 9, 12, 0)) # 2日後へ進める
      expect(reservation.reload).to be_valid
    end
  end

  describe '人数' do
    it '人数は1人以上' do
      reservation = build_reservation(people: 0)
      expect(reservation).not_to be_valid
      expect(reservation.errors[:people]).to be_present
    end

    it '人数は会議室の定員まで' do
      expect(build_reservation(people: 6)).to be_valid
      reservation = build_reservation(people: 7)
      expect(reservation).not_to be_valid
      expect(reservation.errors[:people]).to be_present
    end
  end
end