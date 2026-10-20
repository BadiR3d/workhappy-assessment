class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  before_action :private_response
  helper_method :current_user

  rescue_from ActiveRecord::RecordNotFound do
    render plain: "Assessment not found.", status: :not_found
  end
  rescue_from ActiveRecord::StatementInvalid do |error|
    Rails.logger.warn(event: "database_request_failed", error_class: error.class.name, request_id: request.request_id)
    render plain: "This change could not be saved. Please retry or contact your administrator.", status: :unprocessable_entity
  end

  private

  def current_user
    return @current_user if defined?(@current_user)
    @current_user = User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def require_admin
    unless current_user
      redirect_to login_path, alert: "Sign in to view assessments."
      return
    end
    head :forbidden unless current_user.admin?
  end

  def private_response
    response.headers["Cache-Control"] = "private, no-store"
  end
end
