require 'rails_helper'

# 予約システムチャレンジ Lv3：重複と空き検索
# このテストがすべて通るように、重複のチェックと空き検索のメソッドを作ってください。
# テストのファイルは書き換えないでください。

RSpec.describe 'Lv3 重複と空き検索' do
  include ActiveSupport::Testing::TimeHelpers

  # 「今」を 2030年1月7日（月）8:00 に固定して確かめます
  around do |example|
    travel_to(Time.zone.local(2030, 1, 7, 8, 0)) { example.run }
  end

  let(:room_a) { Room.create!(name: '会議室A', capacity: 6, price_per_30min: 500) }
  let(:room_b) { Room.create!(name: '会議室B', capacity: 10, price_per_30min: 800) }
  let(:user)   { User.create!(name: '山田', email: 'yamada@example.com') }

  def at(hour, min = 0, day: 8)
    Time.zone.local(2030, 1, day, hour, min)
  end

  def reserve(room, start_at, end_at, people: 2)
    Reservation.new(room: room, user: user, start_at: start_at, end_at: end_at, people: people)
  end

  describe '同じ会議室の予約の重なり' do
    # 会議室A に 1月8日 10:00〜12:00 の予約がある状態で確かめます
    let!(:existing) { reserve(room_a, at(10), at(12)).tap(&:save!) }

    it '時間がまったく同じ予約はできない' do
      reservation = reserve(room_a, at(10), at(12))
      expect(reservation).not_to be_valid
      expect(reservation.errors[:base]).to be_present
    end

    it '前の部分が重なる予約はできない（9:00〜10:30）' do
      expect(reserve(room_a, at(9), at(10, 30))).not_to be_valid
    end

    it '後ろの部分が重なる予約はできない（11:30〜13:00）' do
      expect(reserve(room_a, at(11, 30), at(13))).not_to be_valid
    end

    it '内側に入る予約はできない（10:30〜11:00）' do
      expect(reserve(room_a, at(10, 30), at(11))).not_to be_valid
    end

    it '外側から包む予約はできない（9:00〜13:00）' do
      expect(reserve(room_a, at(9), at(13))).not_to be_valid
    end

    it '直前にぴったり続く予約はできる（9:00〜10:00）' do
      expect(reserve(room_a, at(9), at(10))).to be_valid
    end

    it '直後にぴったり続く予約はできる（12:00〜13:00）' do
      expect(reserve(room_a, at(12), at(13))).to be_valid
    end

    it '別の会議室なら、同じ時間でも予約できる' do
      expect(reserve(room_b, at(10), at(12))).to be_valid
    end

    it '別の日なら、同じ時刻でも予約できる' do
      expect(reserve(room_a, at(10, day: 9), at(12, day: 9))).to be_valid
    end

    it 'キャンセル済みの予約とは重なってもよい' do
      existing.update_column(:status, Reservation.statuses[:cancelled])
      expect(reserve(room_a, at(10), at(12))).to be_valid
    end

    it '保存済みの予約を保存し直しても、自分自身とは重ならない' do
      existing.people = 3
      expect(existing).to be_valid
    end
  end

  describe 'Reservation.overlapping(start_at, end_at)（時間が重なる予約）' do
    let!(:morning) { reserve(room_a, at(10), at(12)).tap(&:save!) }
    let!(:noon)    { reserve(room_b, at(12), at(13)).tap(&:save!) }

    it '指定した時間と重なる予約を返す（会議室は問わない）' do
      expect(Reservation.overlapping(at(11), at(12, 30))).to contain_exactly(morning, noon)
    end

    it 'ぴったり隣り合う予約は含まない' do
      expect(Reservation.overlapping(at(9), at(10))).to be_empty
    end
  end

  describe 'Room.available_between(start_at, end_at, people: 1)（空いている会議室）' do
    let!(:room_c) { Room.create!(name: '会議室C', capacity: 2, price_per_30min: 300) }

    before do
      reserve(room_a, at(10), at(12)).save!
    end

    it '指定した時間に予約が入っていない会議室を返す' do
      expect(Room.available_between(at(11), at(12))).to contain_exactly(room_b, room_c)
    end

    it '人数を指定すると、定員が足りる会議室だけを返す' do
      expect(Room.available_between(at(11), at(12), people: 3)).to contain_exactly(room_b)
    end

    it 'キャンセル済みの予約しかない会議室は、空いているとみなす' do
      room_a.reservations.first.update_column(:status, Reservation.statuses[:cancelled])
      expect(Room.available_between(at(11), at(12))).to contain_exactly(room_a, room_b, room_c)
    end
  end

  describe 'Room#free_slots(date)（1日の空き枠）' do
    it '予約がない日は、9:00〜21:00 の30分ごとの枠が24個ある' do
      slots = room_a.free_slots(Date.new(2030, 1, 8))
      expect(slots.size).to eq 24
      expect(slots.first).to eq [at(9), at(9, 30)]
      expect(slots.last).to eq [at(20, 30), at(21)]
    end

    it '予約が入っている時間の枠は含まない' do
      reserve(room_a, at(10), at(12)).save!
      slots = room_a.free_slots(Date.new(2030, 1, 8))
      expect(slots.size).to eq 20
      expect(slots).not_to include([at(10), at(10, 30)])
      expect(slots).not_to include([at(11, 30), at(12)])
      expect(slots).to include([at(12), at(12, 30)])
    end

    it 'キャンセル済みの予約の時間は、空き枠に含まれる' do
      reservation = reserve(room_a, at(10), at(12)).tap(&:save!)
      reservation.update_column(:status, Reservation.statuses[:cancelled])
      expect(room_a.free_slots(Date.new(2030, 1, 8)).size).to eq 24
    end

    it 'ほかの会議室の予約は関係ない' do
      reserve(room_b, at(10), at(12)).save!
      expect(room_a.free_slots(Date.new(2030, 1, 8)).size).to eq 24
    end
  end
end