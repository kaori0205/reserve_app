require 'rails_helper'

# 予約システムチャレンジ Lv5：API（JSON）
# このテストがすべて通るように、ルーティングとコントローラーを作ってください。
# テストのファイルは書き換えないでください。

RSpec.describe 'Lv5 API', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  # 「今」を 2030年1月7日（月）8:00 に固定して確かめます
  around do |example|
    travel_to(Time.zone.local(2030, 1, 7, 8, 0)) { example.run }
  end

  let!(:room_a) { Room.create!(name: '会議室A', capacity: 6, price_per_30min: 500) }
  let!(:room_b) { Room.create!(name: '会議室B', capacity: 10, price_per_30min: 800) }
  let!(:user)   { User.create!(name: '山田', email: 'yamada@example.com') }

  def at(hour, min = 0, day: 8)
    Time.zone.local(2030, 1, day, hour, min)
  end

  def reserve(start_at, end_at, room: room_a)
    Reservation.create!(room: room, user: user, start_at: start_at, end_at: end_at, people: 2)
  end

  def json
    JSON.parse(response.body)
  end

  describe 'GET /api/rooms（会議室の一覧）' do
    it '200 と、会議室の一覧を返す' do
      get '/api/rooms'
      expect(response).to have_http_status(200)
      expect(json.size).to eq 2
    end

    it '各会議室は id・name・capacity・price_per_30min を持ち、id の順に並ぶ' do
      get '/api/rooms'
      expect(json.first).to include(
        'id' => room_a.id, 'name' => '会議室A', 'capacity' => 6, 'price_per_30min' => 500
      )
      expect(json.map { |r| r['id'] }).to eq [room_a.id, room_b.id]
    end
  end

  describe 'GET /api/rooms/:id/availability?date=YYYY-MM-DD（空き枠）' do
    it '200 と、その日の空き枠を「HH:MM」の形で返す' do
      reserve(at(10), at(12))
      get "/api/rooms/#{room_a.id}/availability", params: { date: '2030-01-08' }
      expect(response).to have_http_status(200)
      expect(json['room_id']).to eq room_a.id
      expect(json['date']).to eq '2030-01-08'
      expect(json['free_slots'].size).to eq 20
      expect(json['free_slots'].first).to eq('start' => '09:00', 'end' => '09:30')
      expect(json['free_slots']).not_to include('start' => '10:00', 'end' => '10:30')
    end

    it 'date がないときは 400 と error を返す' do
      get "/api/rooms/#{room_a.id}/availability"
      expect(response).to have_http_status(400)
      expect(json['error']).to be_present
    end

    it 'date が日付として読めないときも 400 と error を返す' do
      get "/api/rooms/#{room_a.id}/availability", params: { date: 'abc' }
      expect(response).to have_http_status(400)
      expect(json['error']).to be_present
    end

    it '存在しない会議室なら 404 と error を返す' do
      get '/api/rooms/0/availability', params: { date: '2030-01-08' }
      expect(response).to have_http_status(404)
      expect(json['error']).to be_present
    end
  end

  describe 'POST /api/reservations（予約の作成）' do
    let(:valid_params) do
      { reservation: { room_id: room_a.id, user_id: user.id,
                       start_at: '2030-01-08T17:00:00+09:00', end_at: '2030-01-08T19:00:00+09:00', people: 3 } }
    end

    it '201 と、作った予約を返す' do
      expect { post '/api/reservations', params: valid_params, as: :json }.to change(Reservation, :count).by(1)
      expect(response).to have_http_status(201)
      expect(json).to include('room_id' => room_a.id, 'user_id' => user.id, 'people' => 3, 'status' => 'reserved')
      expect(json['id']).to eq Reservation.last.id
      expect(Time.zone.parse(json['start_at'])).to eq at(17)
      expect(Time.zone.parse(json['end_at'])).to eq at(19)
    end

    it '返す予約には料金（price）も入っている' do
      post '/api/reservations', params: valid_params, as: :json
      expect(json['price']).to eq 2250
    end

    it 'ルールに合わないときは 422 と、エラーの文の配列（errors）を返す' do
      params = valid_params.deep_merge(reservation: { people: 7 })
      expect { post '/api/reservations', params: params, as: :json }.not_to change(Reservation, :count)
      expect(response).to have_http_status(422)
      expect(json['errors']).to be_an(Array)
      expect(json['errors']).not_to be_empty
      expect(json['errors']).to all(be_a(String))
    end

    it 'ほかの予約と重なるときも 422' do
      reserve(at(18), at(20))
      post '/api/reservations', params: valid_params, as: :json
      expect(response).to have_http_status(422)
    end

    it '会議室の指定がないときも 422（404 ではない）' do
      params = valid_params.deep_merge(reservation: { room_id: nil })
      post '/api/reservations', params: params, as: :json
      expect(response).to have_http_status(422)
    end
  end

  describe 'DELETE /api/reservations/:id（キャンセル）' do
    it '200 と、キャンセル済みになった予約を返す（予約自体は消さない）' do
      reservation = reserve(at(10), at(11))
      expect { delete "/api/reservations/#{reservation.id}" }.not_to change(Reservation, :count)
      expect(response).to have_http_status(200)
      expect(json['id']).to eq reservation.id
      expect(json['status']).to eq 'cancelled'
      expect(reservation.reload).to be_cancelled
    end

    it '当日の予約は 422 と errors を返し、キャンセルしない' do
      reservation = reserve(at(10, day: 7), at(11, day: 7))
      delete "/api/reservations/#{reservation.id}"
      expect(response).to have_http_status(422)
      expect(json['errors']).not_to be_empty
      expect(reservation.reload).to be_reserved
    end

    it '存在しない予約なら 404 と error を返す' do
      delete '/api/reservations/0'
      expect(response).to have_http_status(404)
      expect(json['error']).to be_present
    end
  end

  describe 'GET /api/users/:id/reservations（利用者のこれからの予約）' do
    it '200 と、その人のこれからの予約を開始が早い順に返す' do
      later  = reserve(at(15, day: 9), at(16, day: 9))
      sooner = reserve(at(10), at(11), room: room_b)
      reserve(at(13), at(14)).cancel!
      get "/api/users/#{user.id}/reservations"
      expect(response).to have_http_status(200)
      expect(json.map { |r| r['id'] }).to eq [sooner.id, later.id]
      expect(json.first).to include('room_id' => room_b.id, 'status' => 'reserved', 'price' => 1600)
    end
  end
end