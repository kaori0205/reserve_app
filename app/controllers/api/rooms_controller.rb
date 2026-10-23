class Api::RoomsController < Api::BaseController
  def index
    rooms = Room.order(:id)
    render json: rooms
  end

  def availability
    room = Room.find(params[:id])

    # 日付のパース（エラーが起きたら 400 を返して終了する）
    date = begin
      Date.iso8601(params[:date].to_s)
    rescue Date::Error
      render json: { error: 'Invalid date' }, status: :bad_request
      return
    end

    # room.free_slots(date) の結果（配列）を、指定されたフォーマットに変換する
    free_slots = room.free_slots(date).map do |start_time, end_time|
      {
        'start' => start_time.strftime('%H:%M'),
        'end'   => end_time.strftime('%H:%M')
      }
    end

    # テストが期待するハッシュの形（room_id, date, free_slots）で返す
    render json: {
      room_id: room.id,
      date: params[:date],
      free_slots: free_slots
    }
  end
end