class Api::HelloController < ActionController::API
  def index
      rooms = Room.order(:id)
      render json: rooms
  end

  def availability
    room = Room.find(params[:id])

    date = Date.iso8601(params[:date].to_s)
      rescue Date::Error
        nil
      end

    slots = room.free_slots(date)
    
    render json: slots
  end
end