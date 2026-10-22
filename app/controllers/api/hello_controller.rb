class Api::HelloController < ActionController::API
  def show
    name = params[:name]
    if name.blank?
      render json: { error: 'name を指定してください' }, status: :bad_request
    else
      render json: { message: "こんにちは、#{name}さん" }
    end
  end
end