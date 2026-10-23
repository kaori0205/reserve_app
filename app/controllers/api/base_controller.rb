class Api::BaseController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound do
  render json: { error: '見つかりません' }, status: :not_found
  end
  
end