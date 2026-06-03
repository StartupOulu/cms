class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :sites, through: :memberships

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true
  validates :password, length: { minimum: 10 }, allow_nil: true

  def self.create_for_site(site, attrs, role:)
    user = new(attrs)
    return user unless user.valid?

    transaction do
      user.save!
      site.memberships.create!(user: user, role: role)
    end

    user
  rescue ActiveRecord::RecordInvalid => e
    user.errors.add(:base, e.record.errors.full_messages.to_sentence) unless e.record == user
    user
  end

  def display_label
    display_name.presence || email_address
  end

  def member_of?(site)
    memberships.exists?(site: site)
  end

  def admin_of?(site)
    memberships.exists?(site: site, role: "admin")
  end
end
