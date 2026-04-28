class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :site

  delegate :user, to: :session, allow_nil: true
end
