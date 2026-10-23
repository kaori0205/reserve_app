class Api::ReservationsController < Api::BaseController
  def create
    reservation = Reservation.new(reservation_params)

    if reservation.save
      render json: reservation.as_json(only: [:id, :room_id, :user_id, :status, :start_at, :end_at, :people])
                       .merge(price: reservation.price), status: :created
    else
      render json: { errors: reservation.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    reservation = Reservation.find(params[:id])
    if reservation.cancel!
      render json: reservation.as_json(only: [:id, :status])
    else
      render json: { errors: reservation.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def reservation_params
    params.require(:reservation).permit(:room_id, :user_id, :start_at, :end_at, :people)
  end

end