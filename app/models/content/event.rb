module Content
  class Event < ApplicationRecord
    self.table_name = "content_events"

    include Content::Publishable

    serialize :published_fields, coder: JSON

    belongs_to :site
    belongs_to :user

    has_one_attached :cover_image

    validates :title,      presence: true
    validates :slug,       presence: true, uniqueness: { scope: :site_id },
                           format: { with: /\A[a-z0-9-]+\z/, message: "only lowercase letters, numbers, and hyphens" }
    validates :start_time, presence: true
    validate  :cover_image_valid, if: -> { cover_image.attached? }
    validate  :end_time_after_start_time, if: -> { start_time.present? && end_time.present? }

    before_validation :generate_slug, if: -> { slug.blank? && title.present? }

    def jekyll_path
      "_events/#{start_time.strftime("%Y-%m")}-#{slug}.html"
    end

    def jekyll_files_to_delete
      return [] unless published?
      old_path = published_fields&.dig("jekyll_path")
      return [] unless old_path && old_path != jekyll_path
      [old_path]
    end

    def save_published_snapshot!
      update_column(:published_fields, {
        "slug"        => slug,
        "jekyll_path" => jekyll_path,
        "cover_image" => cover_image_bare_filename
      }.compact)
    end

    def clear_published_snapshot!
      update_column(:published_fields, nil)
    end

    def published_slug
      published_fields&.dig("slug")
    end

    def cover_image_path
      cover_image_publish_path || "/assets/images/events/event-placeholder.png"
    end

    def to_html_body
      require "cgi"
      description.present? ? "<p>#{CGI.escapeHTML(description)}</p>" : ""
    end

    def to_markdown
      front_matter = {
        "layout"      => site.content_schema&.dig("events", "layout") || "event",
        "title"       => title,
        "start_time"  => start_time.strftime("%Y-%m-%d %H:%M:%S"),
        "end_time"    => end_time&.strftime("%Y-%m-%d %H:%M:%S"),
        "location"    => location.presence,
        "description" => description.presence,
        "excerpt"     => excerpt.presence,
        "cover_image" => cover_image_bare_filename,
        "cta_title"   => cta_title.presence,
        "cta_link"    => cta_link.presence
      }.compact

      "#{front_matter.to_yaml}---\n"
    end

    private

    def jekyll_files
      files = { jekyll_path => to_markdown }

      if cover_image.attached?
        files[cover_image_publish_path.delete_prefix("/")] = cover_image.blob.download
      end

      files
    end

    def commit_message
      published? ? "Update event: #{title}" : "Publish event: #{title}"
    end

    def cover_image_publish_path
      return nil unless cover_image.attached?
      ext = File.extname(cover_image.blob.filename.to_s)
      "/assets/images/events/#{cover_image.blob.key}#{ext}"
    end

    def cover_image_bare_filename
      return nil unless cover_image.attached?
      ext = File.extname(cover_image.blob.filename.to_s)
      "#{cover_image.blob.key}#{ext}"
    end

    COVER_IMAGE_TYPES = %w[image/jpeg image/png image/webp].freeze
    COVER_IMAGE_MAX   = 10.megabytes

    def cover_image_valid
      blob = cover_image.blob
      unless COVER_IMAGE_TYPES.include?(blob.content_type)
        errors.add(:cover_image, "must be a JPEG, PNG, or WebP")
      end
      if blob.byte_size > COVER_IMAGE_MAX
        errors.add(:cover_image, "must be smaller than 10 MB")
      end
    end

    def end_time_after_start_time
      errors.add(:end_time, "must be after start time") if end_time <= start_time
    end

    def generate_slug
      self.slug = title.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
    end
  end
end
