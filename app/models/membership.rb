class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :site

  validates :role, presence: true, inclusion: { in: Site::ROLES }
  validates :user_id, uniqueness: { scope: :site_id }

  def admin?
    role == "admin"
  end

  def editor?
    role == "editor"
  end
end
