module Content
  module Publishable
    extend ActiveSupport::Concern

    included do
      scope :published, -> { where.not(published_at: nil) }
      scope :draft,     -> { where(published_at: nil) }
      scope :for_site,  ->(site) { where(site: site) }
    end

    def published?
      published_at.present?
    end

    def draft?
      !published?
    end

    def publish!(actor: Current.user)
      site = self.site
      site.commit_and_push(jekyll_files, commit_message, author: site.publish_author,
                           files_to_delete: jekyll_files_to_delete)
      update_column(:published_at, Time.current) unless published?
      save_published_snapshot!
      Audit::Event.record("publish", auditable: self, site: site, user: actor)
    end

    def unpublish!(actor: Current.user)
      site = self.site
      paths = jekyll_files_to_unpublish
      site.commit_and_push({}, "Unpublish: #{title}", author: site.publish_author,
                           files_to_delete: paths)
      update_columns(published_at: nil)
      clear_published_snapshot!
      Audit::Event.record("unpublish", auditable: self, site: site, user: actor)
    end

    def jekyll_files_to_delete
      []
    end

    def jekyll_files_to_unpublish
      [ jekyll_path ]
    end

    def save_published_snapshot!
    end

    def clear_published_snapshot!
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
