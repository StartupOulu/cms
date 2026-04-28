require "fileutils"

module GitTestHelper
  # Sets up a bare origin + working clone, points site.clone_path at the
  # clone for the block, then cleans up. Yields the clone path.
  def with_git_site(site)
    Dir.mktmpdir("cms-test") do |dir|
      seed  = File.join(dir, "seed")
      bare  = File.join(dir, "origin.git")
      clone = File.join(dir, "clone")

      # Seed repo: one empty commit on main so the branch exists
      FileUtils.mkdir_p(seed)
      system("git -C #{seed} init -b main -q")
      system("git -C #{seed} config user.email 'test@example.com'")
      system("git -C #{seed} config user.name 'Test'")
      system("git -C #{seed} commit --allow-empty -m 'init' -q")

      # Bare origin cloned from seed (pushes always accepted to bare repos)
      system("git clone --bare #{seed} #{bare} -q")

      # Working clone the CMS will use
      system("git clone #{bare} #{clone} -q")
      system("git -C #{clone} config user.email 'test@example.com'")
      system("git -C #{clone} config user.name 'Test'")

      site.update_columns(clone_path: clone)
      yield clone
    end
  end
end

ActiveSupport.on_load(:active_support_test_case) { include GitTestHelper }
ActiveSupport.on_load(:action_dispatch_integration_test) { include GitTestHelper }
