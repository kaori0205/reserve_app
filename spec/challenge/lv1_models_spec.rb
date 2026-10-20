require 'rails_helper'

# 予約システムチャレンジ Lv1：モデルと関連
# このテストがすべて通るように、モデル・マイグレーション・設定を作ってください。
# テストのファイルは書き換えないでください。

RSpec.describe 'Lv1 モデルと関連' do
  describe 'アプリの設定' do
    it 'タイムゾーンが東京（Asia/Tokyo）になっている' do
      expect(Time.zone.tzinfo.name).to eq 'Asia/Tokyo'
    end
  end

  describe 'Room（会議室）' do
    def build_room(**attrs)
      Room.new({ name: '会議室A', capacity: 6, price_per_30min: 500 }.merge(attrs))
    end

    it '名前・定員・30分あたりの料金があれば保存できる' do
      expect(build_room).to be_valid
    end

    it '名前（name）は必須' do
      room = build_room(name: '')
      expect(room).not_to be_valid
      expect(room.errors[:name]).to be_present
    end

    it '同じ名前の会議室は登録できない' do
      build_room.save!
      room = build_room
      expect(room).not_to be_valid
      expect(room.errors[:name]).to be_present
    end

    it '定員（capacity）は必須' do
      room = build_room(capacity: nil)
      expect(room).not_to be_valid
      expect(room.errors[:capacity]).to be_present
    end

    it '定員は1人以上' do
      expect(build_room(capacity: 0)).not_to be_valid
      expect(build_room(capacity: 1)).to be_valid
    end

    it '定員は整数' do
      room = build_room(capacity: 2.5)
      expect(room).not_to be_valid
      expect(room.errors[:capacity]).to be_present
    end

    it '30分あたりの料金（price_per_30min）は0円以上の整数' do
      expect(build_room(price_per_30min: -1)).not_to be_valid
      expect(build_room(price_per_30min: 100.5)).not_to be_valid
      expect(build_room(price_per_30min: nil)).not_to be_valid
      expect(build_room(price_per_30min: 0)).to be_valid
    end
  end

  describe 'User（利用者）' do
    it '名前とメールアドレスがあれば保存できる' do
      expect(User.new(name: '山田', email: 'yamada@example.com')).to be_valid
    end

    it '名前（name）は必須' do
      user = User.new(name: '', email: 'yamada@example.com')
      expect(user).not_to be_valid
      expect(user.errors[:name]).to be_present
    end

    it 'メールアドレス（email）は必須' do
      user = User.new(name: '山田', email: '')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to be_present
    end

    it '同じメールアドレスでは登録できない' do
      User.create!(name: '山田', email: 'yamada@example.com')
      user = User.new(name: '山田2', email: 'yamada@example.com')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to be_present
    end
  end

  describe 'Reservation（予約）' do
    let(:room) { Room.create!(name: '会議室A', capacity: 6, price_per_30min: 500) }
    let(:user) { User.create!(name: '山田', email: 'yamada@example.com') }

    it '会議室（room）と利用者（user）に属する' do
      reservation = Reservation.new(room: room, user: user)
      expect(reservation.room).to eq room
      expect(reservation.user).to eq user
    end

    it '会議室がない予約は保存できない' do
      reservation = Reservation.new(user: user, people: 2)
      reservation.valid?
      expect(reservation.errors[:room]).to be_present
    end

    it '利用者がない予約は保存できない' do
      reservation = Reservation.new(room: room, people: 2)
      reservation.valid?
      expect(reservation.errors[:user]).to be_present
    end

    it '人数（people）は必須' do
      reservation = Reservation.new(room: room, user: user, people: nil)
      reservation.valid?
      expect(reservation.errors[:people]).to be_present
    end

    it '開始日時（start_at）と終了日時（end_at）を持てる' do
      start_at = Time.zone.local(2030, 1, 7, 10, 0)
      reservation = Reservation.new(start_at: start_at, end_at: start_at + 1.hour)
      expect(reservation.start_at).to eq start_at
      expect(reservation.end_at).to eq start_at + 1.hour
    end

    it '新しい予約の状態（status）は「予約中（reserved）」から始まる' do
      reservation = Reservation.new
      expect(reservation.status).to eq 'reserved'
      expect(reservation).to be_reserved
    end

    it '状態を「キャンセル済み（cancelled）」にできる' do
      reservation = Reservation.new(status: :cancelled)
      expect(reservation).to be_cancelled
    end
  end

  describe '関連' do
    let(:room) { Room.create!(name: '会議室A', capacity: 6, price_per_30min: 500) }
    let(:user) { User.create!(name: '山田', email: 'yamada@example.com') }
    let(:start_at) { Time.zone.local(2030, 1, 7, 10, 0) }

    # Lv2 以降のルールに関係なく保存するため validate: false を使っています
    let!(:reservation) do
      r = Reservation.new(room: room, user: user, people: 2, start_at: start_at, end_at: start_at + 1.hour)
      r.save!(validate: false)
      r
    end

    it '会議室から、その会議室の予約を取り出せる' do
      expect(room.reservations).to contain_exactly(reservation)
    end

    it '利用者から、その人の予約を取り出せる' do
      expect(user.reservations).to contain_exactly(reservation)
    end

    it '会議室を削除すると、その会議室の予約も削除される' do
      expect { room.destroy }.to change(Reservation, :count).by(-1)
    end
  end
end