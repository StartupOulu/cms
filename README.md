# CMS

An open-source CMS for publishing blog posts and events to Jekyll-based websites via Git. Built for [startupoulu.com](https://startupoulu.com) but designed to be reusable.

- Ruby on Rails 8 · SQLite · Propshaft · Importmap · Solid Queue
- No Docker, no containers — Nginx + Puma + systemd on a plain Linux server
- Git is the source of truth for published content

See `AGENTS.md` for the full architecture, roadmap, and contributor guide.

---

## Local development

**Requirements:** Ruby 3.4+, Git

```sh
git clone <this-repo> cms
cd cms
bin/setup
bin/dev
```

`bin/setup` installs gems, creates the SQLite databases, and runs migrations.  
`bin/dev` starts Puma (and Solid Queue in dev).

There is no first-run wizard. Follow the console recipes below to create a site and admin user.

### Console setup (dev)

```ruby
bin/rails console

site = Site.create!(
  slug:                 "mysite",
  name:                 "My Site",
  repo_url:             "git@github.com:org/repo.git",
  branch:               "main",
  site_url:             "https://example.com",
  publish_author_name:  "CMS Bot",
  publish_author_email: "cms@example.com",
  clone_path:           Rails.root.join("shared/repos/mysite").to_s
)

user = User.create!(
  email_address: "you@example.com",
  password:      "changeme",
  display_name:  "Your Name"
)

Membership.create!(user: user, site: site, role: "admin")
```

Visit `http://localhost:3000` and sign in.

---

## Production setup

See `docs/deployment.md` for the complete walkthrough. Short version:

### 1. Create the first site and admin user

```sh
RAILS_ENV=production bin/rails console
```

```ruby
site = Site.create!(
  name: "My Site", slug: "mysite",
  repo_url: "git@github.com:org/repo.git", branch: "main",
  site_url: "https://example.com",
  clone_path: "/var/www/apps/cms/shared/repos/mysite",
  deploy_key_path: "/var/www/apps/cms/shared/ssh/mysite/id_ed25519",
  publish_author_name: "CMS Bot", publish_author_email: "cms@example.com"
)

user = User.create!(
  email_address: "you@example.com", display_name: "Your Name",
  password: "change-this-on-first-login", must_change_password: true
)

site.memberships.create!(user: user, role: "admin")
```

### 2. Clone the website repo

```sh
GIT_SSH_COMMAND="ssh -i /var/www/apps/cms/shared/ssh/mysite/id_ed25519 -o StrictHostKeyChecking=no" \
  git clone git@github.com:org/repo.git /var/www/apps/cms/shared/repos/mysite
```

The deploy key (`id_ed25519.pub`) must be added to the website repo on GitHub under **Settings → Deploy keys** with write access.

### 3. Deploy

```sh
bin/deplou
```

---

## Running tests

```sh
bin/rails test
```

Tests use SQLite and a real temporary git repository for publish integration tests. No external services required.

---

## License

To be decided before first external contribution. Leaning MIT or Apache 2.0.
