require "open3"
require "fileutils"

class Site < ApplicationRecord
  ROLES = %w[editor admin].freeze

  serialize :content_schema, coder: JSON

  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :content_posts, class_name: "Content::Post", dependent: :destroy
  has_many :audit_events, class_name: "Audit::Event", dependent: :destroy

  validates :slug,                 presence: true, uniqueness: true,
                                   format: { with: /\A[a-z0-9-]+\z/, message: "only lowercase letters, numbers, and hyphens" }
  validates :name,                 presence: true
  validates :repo_url,             presence: true
  validates :branch,               presence: true
  validates :site_url,             presence: true
  validates :publish_author_name,  presence: true
  validates :publish_author_email, presence: true
  validates :clone_path,           presence: true

  GitCheck = Struct.new(:label, :ok, :error)

  # Liquid's LocalFileSystem only allows [a-zA-Z0-9_/-] in include names,
  # but Jekyll includes use full filenames with dots (e.g. header.html).
  class JekyllFileSystem < Liquid::LocalFileSystem
    def read_template_file(template_name)
      source = super
      # Normalise Jekyll-style unquoted includes inside included files too
      source.gsub(/(\{%-?\s*include\s+)(?!['"])([^\s%}'"]+)/) { "#{$1}'#{$2}'" }
    end

    def full_path(template_name)
      raise Liquid::FileSystemError, "Illegal template name '#{template_name}'" unless
        template_name =~ /\A[a-zA-Z0-9_\/\-\.]+\z/
      full = File.join(root, @pattern % template_name)
      raise Liquid::FileSystemError, "Illegal template path '#{full}'" unless
        File.expand_path(full).start_with?(File.expand_path(root))
      full
    end
  end

  def publish_author
    "#{publish_author_name} <#{publish_author_email}>"
  end

  def membership_for(user)
    memberships.find_by(user: user)
  end

  def render_preview(post)
    require "liquid"
    require "yaml"

    config      = load_jekyll_config
    page_vars   = preview_page_vars(post, config)
    content_html = post.to_html_body

    render_layout(page_vars["layout"] || "default", content_html, page_vars, config)
  rescue PreviewError
    raise
  rescue => e
    raise PreviewError, e.message
  end

  def check_git
    checks = []

    unless File.directory?(clone_path) && git_rev_parse_ok?
      checks << GitCheck.new("Repository cloned", false,
        "No git repository found at #{clone_path}. " \
        "Run: git clone #{repo_url} #{clone_path}")
      return checks
    end
    checks << GitCheck.new("Repository cloned", true, nil)

    actual_url, _, status = Open3.capture3("git", "remote", "get-url", "origin", chdir: clone_path)
    actual_url = actual_url.strip
    unless status.success? && actual_url == repo_url
      checks << GitCheck.new("Remote URL", false,
        "Expected #{repo_url}, got #{actual_url.presence || '(none)'}")
      return checks
    end
    checks << GitCheck.new("Remote URL", true, nil)

    env = deploy_key_path.present? ? { "GIT_SSH_COMMAND" => "ssh -i #{deploy_key_path} -o StrictHostKeyChecking=no" } : {}
    out, stderr, status = Open3.capture3(env, "git", "ls-remote", "--heads", "origin", branch, chdir: clone_path)
    unless status.success? && out.include?(branch)
      checks << GitCheck.new("Remote branch", false,
        stderr.strip.presence || "Branch '#{branch}' not found on remote")
      return checks
    end
    checks << GitCheck.new("Remote branch", true, nil)

    checks
  end

  def commit_and_push(files, message, author:, files_to_delete: [])
    with_publish_lock do
      in_repo do
        git "fetch", "origin"
        git "reset", "--hard", "origin/#{branch}"

        files_to_delete.each { |path| git "rm", "--force", "--ignore-unmatch", path }

        files.each do |path, content|
          full_path = File.join(clone_path, path)
          FileUtils.mkdir_p(File.dirname(full_path))
          File.binwrite(full_path, content)
          git "add", path
        end

        git "commit", "--author=#{author}", "-m", message
        git "push", "origin", branch
      end
    end
  end

  private

  def load_jekyll_config
    path = File.join(clone_path, "_config.yml")
    File.exist?(path) ? (YAML.safe_load_file(path) || {}) : {}
  end

  def preview_page_vars(post, config)
    layout = config.dig("defaults")&.find { |d|
      d.dig("scope", "type") == "posts"
    }&.dig("values", "layout") || "blog"

    {
      "title"       => post.title,
      "description" => post.description.to_s,
      "blog_image"  => post.blog_image_path,
      "layout"      => layout,
      "url"         => "/#{Time.current.strftime("%Y/%m/%d")}/#{post.slug}/"
    }
  end

  def render_layout(layout_name, content, page_vars, site_config, depth = 0)
    raise PreviewError, "Layout nesting too deep" if depth > 5

    layout_file = File.join(clone_path, "_layouts", "#{layout_name}.html")
    unless File.exist?(layout_file)
      raise PreviewError, "Layout '#{layout_name}' not found in #{clone_path}/_layouts/"
    end

    raw = File.read(layout_file)
    layout_front_matter, layout_body = extract_front_matter(raw)

    fs = JekyllFileSystem.new(File.join(clone_path, "_includes"), "%s")
    template = Liquid::Template.parse(normalize_liquid(layout_body))
    rendered = template.render(
      { "page" => page_vars, "site" => site_config, "content" => content },
      registers: { file_system: fs }
    )

    parent = layout_front_matter["layout"]
    parent ? render_layout(parent, rendered, page_vars, site_config, depth + 1) : rendered
  end

  # Jekyll allows unquoted include names: {% include header.html %}
  # Liquid requires quoted strings:      {% include 'header.html' %}
  def normalize_liquid(source)
    source.gsub(/(\{%-?\s*include\s+)(?!['"])([^\s%}'"]+)/) do
      "#{$1}'#{$2}'"
    end
  end

  def extract_front_matter(source)
    if source =~ /\A---\s*\n(.*?\n?)---\s*\n(.*)/m
      [(YAML.safe_load($1) || {}), $2]
    else
      [{}, source]
    end
  end

  def with_publish_lock
    lock_path = Rails.root.join("shared", "locks", "#{slug}.lock")
    FileUtils.mkdir_p(File.dirname(lock_path))
    File.open(lock_path, File::RDWR | File::CREAT, 0o644) do |f|
      f.flock(File::LOCK_EX)
      yield
    end
  end

  def in_repo
    FileUtils.mkdir_p(clone_path)
    yield
  end

  def git_rev_parse_ok?
    _, _, status = Open3.capture3("git", "rev-parse", "--git-dir", chdir: clone_path)
    status.success?
  end

  def git(*args)
    env = deploy_key_path.present? ? { "GIT_SSH_COMMAND" => "ssh -i #{deploy_key_path} -o StrictHostKeyChecking=no" } : {}
    stdout, stderr, status = Open3.capture3(env, "git", *args, chdir: clone_path)
    raise PublishError, stderr.presence || "git #{args.first} failed" unless status.success?
    stdout
  end
end
