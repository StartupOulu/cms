module Content
  module Publishable
    extend ActiveSupport::Concern

    # Published asset filenames are derived from the record's slug, so the
    # extension has to be canonical and lowercase rather than whatever the
    # uploader happened to name the file.
    IMAGE_EXTENSIONS = {
      "image/jpeg" => ".jpg",
      "image/png"  => ".png",
      "image/webp" => ".webp"
    }.freeze

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
      begin
        site.commit_and_push(jekyll_files, commit_message, author: site.publish_author,
                             files_to_delete: jekyll_files_to_delete)
      rescue PublishError => e
        Audit::Event.record("publish_failed", auditable: self, site: site, user: actor, error: e)
        raise
      end
      update_column(:published_at, Time.current) unless published?
      save_published_snapshot!
      Audit::Event.record("publish", auditable: self, site: site, user: actor)
    end

    def unpublish!(actor: Current.user)
      site = self.site
      paths = jekyll_files_to_unpublish
      begin
        site.commit_and_push({}, "Unpublish: #{title}", author: site.publish_author,
                             files_to_delete: paths)
      rescue PublishError => e
        Audit::Event.record("publish_failed", auditable: self, site: site, user: actor, error: e)
        raise
      end
      update_columns(published_at: nil)
      clear_published_snapshot!
      Audit::Event.record("unpublish", auditable: self, site: site, user: actor)
    end

    def jekyll_files_to_delete
      []
    end

    def jekyll_files_to_unpublish
      [ jekyll_path ] + published_asset_paths
    end

    # Repo-relative paths (no leading slash) of every image this record publishes
    # alongside its markdown.
    def jekyll_asset_paths
      []
    end

    # What the previous publish wrote. Assets it wrote but the current version no
    # longer refers to are orphans and get removed on the next publish.
    def published_asset_paths
      fields = published_fields
      return [] unless fields
      fields.key?("assets") ? Array(fields["assets"]).compact : legacy_published_asset_paths
    end

    def orphaned_asset_paths
      published_asset_paths - jekyll_asset_paths
    end

    def save_published_snapshot!
    end

    def clear_published_snapshot!
    end

    private

    # Snapshots written before assets were tracked recorded only the cover image
    # under a per-model key. Subclasses translate that into a repo-relative path
    # so the first publish after this change still cleans up its predecessor.
    def legacy_published_asset_paths
      []
    end

    def image_extension(blob)
      IMAGE_EXTENSIONS[blob.content_type] || File.extname(blob.filename.to_s).downcase
    end

    def jekyll_files
      raise NotImplementedError, "#{self.class}#jekyll_files must be implemented"
    end

    def commit_message
      raise NotImplementedError, "#{self.class}#commit_message must be implemented"
    end
  end
end
