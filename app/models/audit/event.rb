module Audit
  class Event < ApplicationRecord
    self.table_name = "audit_events"

    belongs_to :site
    belongs_to :user

    validates :action, presence: true

    def self.record(action, auditable:, site: Current.site, user: Current.user)
      create!(
        action:         action,
        auditable_type: auditable.class.name,
        auditable_id:   auditable.id,
        site:           site,
        user:           user
      )
    end
  end
end
