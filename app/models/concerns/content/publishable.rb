module Content
  module Publishable
    extend ActiveSupport::Concern

    included do
      scope :published, -> { where.not(published_at: nil) }
      scope :for_site,  ->(site) { where(site: site) }
    end

    def published?
      published_at.present?
    end

    def publish!(actor: Current.user)
      site = self.site
      site.commit_and_push(jekyll_files, commit_message, author: site.publish_author)

      touch(:published_at) unless published?
      update_column(:published_at, Time.current)

      Audit::Event.record("publish", auditable: self, site: site, user: actor)
    end

    private

    def jekyll_files
      raise NotImplementedError, "#{self.class}#jekyll_files must be implemented"
    end

    def commit_message
      raise NotImplementedError, "#{self.class}#commit_message must be implemented"
    end
  end
end
