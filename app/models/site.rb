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

  def publish_author
    "#{publish_author_name} <#{publish_author_email}>"
  end

  def membership_for(user)
    memberships.find_by(user: user)
  end

  def commit_and_push(files, message, author:)
    with_publish_lock do
      in_repo do
        git "fetch", "origin"
        git "reset", "--hard", "origin/#{branch}"

        files.each do |path, content|
          full_path = File.join(clone_path, path)
          FileUtils.mkdir_p(File.dirname(full_path))
          File.write(full_path, content)
          git "add", path
        end

        git "commit", "--author=#{author}", "-m", message
        git "push", "origin", branch
      end
    end
  end

  private

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

  def git(*args)
    env = deploy_key_path.present? ? { "GIT_SSH_COMMAND" => "ssh -i #{deploy_key_path} -o StrictHostKeyChecking=no" } : {}
    stdout, stderr, status = Open3.capture3(env, "git", *args, chdir: clone_path)
    raise PublishError, stderr.presence || "git #{args.first} failed" unless status.success?
    stdout
  end
end
