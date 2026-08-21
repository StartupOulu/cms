module Content
  class Post < ApplicationRecord
    self.table_name = "content_posts"

    include Content::Publishable

    serialize :blocks,           coder: JSON
    serialize :published_blocks, coder: JSON
    serialize :published_fields, coder: JSON

    belongs_to :site
    belongs_to :user

    has_one_attached :cover_image

    validates :title,  presence: true
    validates :slug,   presence: true, uniqueness: { scope: :site_id },
                       format: { with: /\A[a-z0-9-]+\z/, message: "only lowercase letters, numbers, and hyphens" }
    validates :blocks, presence: true
    validate :cover_image_valid, if: -> { cover_image.attached? }

    before_validation :generate_slug, if: -> { slug.blank? && title.present? }

    def jekyll_path
      date = (published_at || Time.current).strftime("%Y-%m-%d")
      "_posts/#{date}-#{slug}.markdown"
    end

    def draft_path
      "_drafts/#{slug}.markdown"
    end

    def jekyll_files_to_delete
      return [] unless published?
      paths = []
      if published_slug && published_slug != slug
        date = published_at.strftime("%Y-%m-%d")
        paths << "_posts/#{date}-#{published_slug}.markdown"
      end
      paths + orphaned_asset_paths
    end

    def jekyll_asset_paths
      asset_attachments.map { |path, _blob| path.delete_prefix("/") }
    end

    def save_published_snapshot!
      update_column(:published_fields, {
        "description" => description,
        "slug"        => slug,
        "cover_image" => cover_image_publish_path,
        "assets"      => jekyll_asset_paths
      }.compact)
      update_column(:published_blocks, blocks)
    end

    def clear_published_snapshot!
      update_column(:published_fields, nil)
      update_column(:published_blocks, nil)
    end

    def pending_changes?
      blocks != published_blocks
    end

    def published_slug
      published_fields&.dig("slug")
    end

    def published_description
      published_fields&.dig("description")
    end

    def to_html_body
      require "cgi"
      (blocks || []).map { |b| block_to_html(b) }.compact.join("\n")
    end

    def blog_image_path
      cover_image_publish_path || "/assets/images/blogs/blog-placeholder.png"
    end

    def to_markdown
      front_matter = {
        "layout"      => site.content_schema&.dig("posts", "layout") || "blog",
        "title"       => title,
        "description" => description.to_s,
        "blog_image"  => blog_image_path
      }

      "#{front_matter.to_yaml}---\n\n#{serialize_blocks(blocks)}"
    end

    private

    # Named after the post itself (2026-08-founders-corner.png) rather than the
    # opaque ActiveStorage key, matching how the site's images are named by hand.
    def asset_basename
      "#{(published_at || Time.current).strftime("%Y-%m")}-#{slug}"
    end

    # Every image this post publishes, paired with the blob to write there.
    # jekyll_files and jekyll_asset_paths both read from this so the files
    # written and the files tracked can never drift apart.
    def asset_attachments
      attachments = []
      attachments << [ cover_image_publish_path, cover_image.blob ] if cover_image.attached?

      (blocks || []).each do |block|
        blob = inline_image_blob(block)
        next unless blob
        attachments << [ inline_image_path(blob, block), blob ]
      end

      attachments.uniq { |path, _blob| path }
    end

    def legacy_published_asset_paths
      path = published_fields&.dig("cover_image")
      path.present? ? [ path.delete_prefix("/") ] : []
    end

    def jekyll_files
      files = { jekyll_path => to_markdown }
      asset_attachments.each { |path, blob| files[path.delete_prefix("/")] = blob.download }
      files
    end

    def commit_message
      published? ? "Update: #{title}" : "Publish: #{title}"
    end

    def cover_image_publish_path
      return nil unless cover_image.attached?
      "/assets/images/blogs/#{asset_basename}#{image_extension(cover_image.blob)}"
    end

    def inline_image_blob(block)
      return nil unless block["type"] == "image" && block["signed_id"].present?
      ActiveStorage::Blob.find_signed(block["signed_id"])
    end

    # Numbered by the order the image blocks appear, so reordering a post renames
    # its images — the stale names are cleaned up as orphans on the next publish.
    def inline_image_path(blob, block)
      "/assets/images/blogs/#{asset_basename}-#{inline_image_position(block)}#{image_extension(blob)}"
    end

    def inline_image_position(block)
      signed_ids = (blocks || []).filter_map do |b|
        b["signed_id"] if b["type"] == "image" && b["signed_id"].present?
      end.uniq
      signed_ids.index(block["signed_id"]).to_i + 1
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

    def generate_slug
      self.slug = title.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
    end

    def block_to_html(block)
      e = ->(s) { CGI.escapeHTML(s.to_s) }
      case block["type"]
      when "paragraph"
        "<p>#{inline_md(block["content"])}</p>"
      when "heading"
        level = block["level"].to_i.clamp(1, 6)
        "<h#{level}>#{inline_md(block["content"])}</h#{level}>"
      when "ul"
        items = block["items"].map { |i| "<li>#{inline_md(i)}</li>" }.join
        "<ul>#{items}</ul>"
      when "ol"
        items = block["items"].map { |i| "<li>#{inline_md(i)}</li>" }.join
        "<ol>#{items}</ol>"
      when "image"
        blob = inline_image_blob(block)
        return nil unless blob
        "<figure><img src=\"#{inline_image_path(blob, block)}\" alt=\"#{e.(block["alt"])}\"></figure>"
      end
    end

    def inline_md(text)
      result = CGI.escapeHTML(text.to_s)
      result = result.gsub(/\*\*(.+?)\*\*/m) { "<strong>#{$1}</strong>" }
      result = result.gsub(/\*(.+?)\*/m)     { "<em>#{$1}</em>" }
      result = result.gsub(/\[([^\]]+)\]\(([^)]+)\)/) do
        label, url = $1, $2
        url.match?(/\Ahttps?:\/\/|\A\//) ? "<a href=\"#{url}\">#{label}</a>" : label
      end
      result
    end

    def serialize_blocks(blocks)
      return "" if blocks.blank?
      blocks.map { |b| serialize_block(b) }.compact.join("\n\n")
    end

    def serialize_block(block)
      case block["type"]
      when "paragraph" then block["content"].to_s
      when "heading"   then "#{"#" * block["level"].to_i} #{block["content"]}"
      when "ul"        then block["items"].map { |i| "- #{i}" }.join("\n")
      when "ol"        then block["items"].each_with_index.map { |i, n| "#{n + 1}. #{i}" }.join("\n")
      when "image"
        blob = inline_image_blob(block)
        blob ? "![#{block["alt"]}](#{inline_image_path(blob, block)})" : nil
      end
    end
  end
end
