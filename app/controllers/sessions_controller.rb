class SessionsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :create,
    with: -> { render plain: "Too many sign-in attempts. Please try again in a few minutes.", status: :too_many_requests }

  def new
    redirect_to assessments_path if current_user&.admin?
  end

  def create
    email = params[:email].is_a?(String) ? params[:email].strip.downcase : ""
    password = params[:password].is_a?(String) ? params[:password] : ""
    user = User.find_by(email: email)
    # A missing account still performs a bcrypt comparison.
    digest = user&.password_digest || User.dummy_password_digest
    authenticated = BCrypt::Password.new(digest).is_password?(password)
    if user && authenticated
      reset_session
      session[:user_id] = user.id
      redirect_to assessments_path, status: :see_other
    else
      flash.now[:alert] = "Email or password was not recognised."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to login_path, status: :see_other
  end
end
