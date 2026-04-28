require "open3"
require "fileutils"

def cms_parse_author(str)
  str =~ /\A(.+)\s+<(.+)>\z/ ? [ $1.strip, $2.strip ] : [ str, str ]
end

namespace :cms do
  namespace :sites do
    desc <<~DESC
      Create a site and generate its deploy keypair.

      Usage:
        bin/rails cms:sites:create -- \\
          --slug=startupoulu \\
          --name="StartupOulu" \\
          --repo-url=git@github.com:startupoulu/startupoulu.github.io.git \\
          --branch=main \\
          --site-url=https://startupoulu.com \\
          --publish-author="CMS Bot <cms@startupoulu.com>"

      After running, add the printed public key to the website repo's deploy keys
      (Settings → Deploy keys → Add deploy key, tick "Allow write access"), then
      pass --clone to clone the repo, or clone manually.
    DESC
    task create: :environment do
      options = { branch: "main" }
      extra   = ARGV.drop_while { |a| a != "--" }.drop(1)

      require "optparse"
      OptionParser.new do |opts|
        opts.on("--slug=SLUG")               { |v| options[:slug] = v }
        opts.on("--name=NAME")               { |v| options[:name] = v }
        opts.on("--repo-url=URL")            { |v| options[:repo_url] = v }
        opts.on("--branch=BRANCH")           { |v| options[:branch] = v }
        opts.on("--site-url=URL")            { |v| options[:site_url] = v }
        opts.on("--publish-author=AUTHOR")   { |v| options[:publish_author] = v }
        opts.on("--clone")                   { options[:clone] = true }
      end.parse!(extra)

      %i[slug name repo_url site_url publish_author].each do |key|
        abort "Missing required option: --#{key.to_s.tr('_', '-')}" unless options[key]
      end

      slug   = options[:slug]
      author_name, author_email = cms_parse_author(options[:publish_author])
      clone_path = Rails.root.join("shared", "repos", slug).to_s
      key_dir    = Rails.root.join("shared", "ssh", slug).to_s
      key_path   = File.join(key_dir, "id_ed25519")

      abort "Site '#{slug}' already exists." if Site.exists?(slug: slug)

      FileUtils.mkdir_p(key_dir)

      puts "Generating deploy keypair…"
      _, stderr, status = Open3.capture3("ssh-keygen", "-t", "ed25519", "-C", "cms-#{slug}",
                                          "-f", key_path, "-N", "")
      abort "ssh-keygen failed: #{stderr}" unless status.success?

      public_key = File.read("#{key_path}.pub").strip

      site = Site.create!(
        slug:                 slug,
        name:                 options[:name],
        repo_url:             options[:repo_url],
        branch:               options[:branch],
        site_url:             options[:site_url],
        publish_author_name:  author_name,
        publish_author_email: author_email,
        clone_path:           clone_path,
        deploy_key_path:      key_path
      )

      puts ""
      puts "Site '#{site.name}' created (id=#{site.id})"
      puts ""
      puts "Deploy public key — add to the website repo's deploy keys"
      puts "(Settings → Deploy keys → Add deploy key, tick Allow write access):"
      puts ""
      puts public_key
      puts ""

      ssh_cmd = "ssh -i #{key_path} -o StrictHostKeyChecking=no"

      if options[:clone]
        puts "Cloning #{options[:repo_url]}…"
        FileUtils.mkdir_p(clone_path)
        _, clone_stderr, clone_status = Open3.capture3(
          { "GIT_SSH_COMMAND" => ssh_cmd },
          "git", "clone", options[:repo_url], clone_path
        )
        if clone_status.success?
          puts "Cloned to #{clone_path}"
        else
          puts "Clone failed (deploy key not yet added?): #{clone_stderr.strip}"
          puts "Run manually once the key is added:"
          puts "  GIT_SSH_COMMAND='#{ssh_cmd}' git clone #{options[:repo_url]} #{clone_path}"
        end
      else
        puts "Once the deploy key is added, clone the repo:"
        puts "  GIT_SSH_COMMAND='#{ssh_cmd}' \\"
        puts "    git clone #{options[:repo_url]} #{clone_path}"
      end

      puts ""
      puts "Then create the admin user in the Rails console:"
      puts "  user = User.create!(email_address: 'you@example.com', password: 'changeme', display_name: 'Your Name')"
      puts "  Membership.create!(user: user, site: Site.find(#{site.id}), role: 'admin')"

      exit 0
    end
  end
end
