module Audit
  class Event < ApplicationRecord
    self.table_name = "audit_events"

    belongs_to :site
    belongs_to :user

    validates :action, presence: true

    HUMAN_ACTIONS = {
      "publish"        => "published",
      "unpublish"      => "unpublished",
      "publish_failed" => "failed to publish"
    }.freeze

    scope :unacknowledged_failures, -> {
      where(action: "publish_failed", acknowledged_at: nil)
    }

    def self.record(action, auditable:, site: Current.site, user: Current.user, error: nil)
      create!(
        action:         action,
        auditable_type: auditable.class.name,
        auditable_id:   auditable.id,
        title:          auditable.title,
        site:           site,
        user:           user,
        error_message:  error&.message
      )
    end

    def human_action
      HUMAN_ACTIONS.fetch(action, action)
    end

    def failed?
      action == "publish_failed"
    end
  end
end
