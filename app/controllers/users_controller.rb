class UsersController < ApplicationController
  before_action :require_admin

  def index
    @memberships = Current.site.memberships.includes(:user).order(:created_at)
  end

  def new
    @user = User.new
  end

  def create
    temp_password = SecureRandom.alphanumeric(12)
    @user = User.new(
      email_address:        user_params[:email_address],
      display_name:         user_params[:display_name].presence,
      password:             temp_password,
      must_change_password: true
    )

    ActiveRecord::Base.transaction do
      @user.save!
      Current.site.memberships.create!(user: @user, role: role_param)
    end

    session[:new_user_creds] = { "email" => @user.email_address, "password" => temp_password }
    redirect_to user_credentials_path
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def credentials
    creds = session.delete(:new_user_creds)
    return redirect_to users_path, alert: "No credentials to display." unless creds
    @user_email  = creds["email"]
    @temp_password = creds["password"]
  end

  private

  def require_admin
    redirect_to root_path, alert: "Not authorised." unless Current.user.admin_of?(Current.site)
  end

  def user_params
    params.require(:user).permit(:email_address, :display_name, :role)
  end

  def role_param
    user_params[:role].presence_in(%w[editor admin]) || "editor"
  end
end
