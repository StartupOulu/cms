class PasswordChangesController < ApplicationController
  skip_before_action :require_password_change

  def edit; end

  def update
    if params[:password].blank?
      flash.now[:alert] = "Password can't be blank."
      return render :edit, status: :unprocessable_entity
    end

    if params[:password] != params[:password_confirmation]
      flash.now[:alert] = "Passwords don't match."
      return render :edit, status: :unprocessable_entity
    end

    Current.user.update!(password: params[:password], must_change_password: false)
    redirect_to root_path, notice: "Password updated. Welcome!"
  end
end
