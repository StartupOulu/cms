require "open3"
require "fileutils"

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

      After running:
        1. Copy the printed public key into the website repo's deploy keys
           (Settings → Deploy keys → Add deploy key, tick "Allow write access").
        2. Then clone the repo:
             git clone --config core.sshCommand="ssh -i KEYPATH" REPO_URL CLONE_PATH
           Or re-run with --clone to have this task do it automatically.
    DESC
    task create: :environment do
      require "optparse"

      options = { branch: "main" }
      OptionParser.new do |opts|
        opts.on("--slug=SLUG")                   { |v| options[:slug] = v }
        opts.on("--name=NAME")                   { |v| options[:name] = v }
        opts.on("--repo-url=URL")                { |v| options[:repo_url] = v }
        opts.on("--branch=BRANCH")               { |v| options[:branch] = v }
        opts.on("--site-url=URL")                { |v| options[:site_url] = v }
        opts.on("--publish-author=AUTHOR")       { |v| options[:publish_author] = v }
        opts.on("--clone", "Clone repo now")     { options[:clone] = true }
      end.parse!(ARGV.drop(ARGV.index("--") + 1).map { |a| a.start_with?("--") ? a : nil }.compact)

      %i[slug name repo_url site_url publish_author].each do |key|
        abort "Missing required option: --#{key.to_s.tr('_', '-')}" unless options[key]
      end

      slug   = options[:slug]
      author_name, author_email = parse_author(options[:publish_author])
      clone_path = Rails.root.join("shared", "repos", slug).to_s
      key_dir    = Rails.root.join("shared", "ssh", slug).to_s
      key_path   = File.join(key_dir, "id_ed25519")

      if Site.exists?(slug: slug)
        abort "Site '#{slug}' already exists."
      end

      FileUtils.mkdir_p(key_dir)

      puts "Generating deploy keypair…"
      _, stderr, status = Open3.capture3("ssh-keygen", "-t", "ed25519", "-C", "cms-#{slug}",
                                          "-f", key_path, "-N", "")
      abort "ssh-keygen failed: #{stderr}" unless status.success?

      public_key = File.read("#{key_path}.pub").strip

      site = Site.create!(
        slug:                slug,
        name:                options[:name],
        repo_url:            options[:repo_url],
        branch:              options[:branch],
        site_url:            options[:site_url],
        publish_author_name:  author_name,
        publish_author_email: author_email,
        clone_path:          clone_path,
        deploy_key_path:     key_path
      )

      puts ""
      puts "✓ Site '#{site.name}' created (id=#{site.id})"
      puts ""
      puts "Deploy public key — add this to the website repo's deploy keys"
      puts "(Settings → Deploy keys → Add deploy key, tick Allow write access):"
      puts ""
      puts public_key
      puts ""

      if options[:clone]
        puts "Cloning #{options[:repo_url]}…"
        FileUtils.mkdir_p(clone_path)
        ssh_cmd = "ssh -i #{key_path} -o StrictHostKeyChecking=no"
        _, stderr, status = Open3.capture3(
          { "GIT_SSH_COMMAND" => ssh_cmd },
          "git", "clone", options[:repo_url], clone_path
        )
        if status.success?
          puts "✓ Cloned to #{clone_path}"
        else
          puts "Clone failed (deploy key not yet added?): #{stderr.strip}"
          puts "Run manually once the key is added:"
          puts "  GIT_SSH_COMMAND='#{ssh_cmd}' git clone #{options[:repo_url]} #{clone_path}"
        end
      else
        puts "Once the deploy key is added, clone the repo:"
        puts "  GIT_SSH_COMMAND='ssh -i #{key_path} -o StrictHostKeyChecking=no' \\"
        puts "    git clone #{options[:repo_url]} #{clone_path}"
        puts ""
        puts "Then create the admin user:"
        puts "  bin/rails console"
        puts "  > user = User.create!(email_address: 'you@example.com', password: 'changeme', display_name: 'Your Name')"
        puts "  > Membership.create!(user: user, site: Site.find(#{site.id}), role: 'admin')"
      end
    end

    private

    def parse_author(str)
      if str =~ /\A(.+)\s+<(.+)>\z/
        [ $1.strip, $2.strip ]
      else
        [ str, str ]
      end
    end
  end
end
