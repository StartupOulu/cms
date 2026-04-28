module Content
  class Post < ApplicationRecord
    self.table_name = "content_posts"

    include Content::Publishable

    serialize :blocks,           coder: JSON
    serialize :published_blocks, coder: JSON
    serialize :published_fields, coder: JSON

    belongs_to :site
    belongs_to :user

    validates :title,  presence: true
    validates :slug,   presence: true, uniqueness: { scope: :site_id },
                       format: { with: /\A[a-z0-9-]+\z/, message: "only lowercase letters, numbers, and hyphens" }
    validates :blocks, presence: true

    before_validation :generate_slug, if: -> { slug.blank? && title.present? }

    def jekyll_path
      date = (published_at || Time.current).strftime("%Y-%m-%d")
      "_posts/#{date}-#{slug}.markdown"
    end

    def jekyll_files_to_delete
      return [] unless published? && published_slug && published_slug != slug
      date = published_at.strftime("%Y-%m-%d")
      [ "_posts/#{date}-#{published_slug}.markdown" ]
    end

    def save_published_snapshot!
      update_column(:published_fields, { "description" => description, "slug" => slug })
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

    def to_markdown
      front_matter = {
        "layout"      => site.content_schema&.dig("posts", "layout") || "blog",
        "title"       => title,
        "description" => description.presence
      }.compact

      "#{front_matter.to_yaml}---\n\n#{serialize_blocks(blocks)}"
    end

    private

    def jekyll_files
      { jekyll_path => to_markdown }
    end

    def commit_message
      published? ? "Update: #{title}" : "Publish: #{title}"
    end

    def generate_slug
      self.slug = title.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
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
      end
    end
  end
end
