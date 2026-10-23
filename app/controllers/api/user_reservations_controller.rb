class Api::UserReservationsController < Api::BaseController
  def index
    user = User.find(params[:user_id])
    reservations = user.upcoming_reservations

    render json: reservations.map { |r|
      r.as_json(only: [:id, :room_id, :user_id, :status, :start_at, :end_at, :people]).merge(price: r.price)
    }
  end
end