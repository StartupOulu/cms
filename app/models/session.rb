class Session < ApplicationRecord
  belongs_to :user

  after_create :record_sign_in

  private

  def record_sign_in
    user.update_columns(last_signed_in_at: created_at, sign_in_count: user.sign_in_count + 1)
  end
end
