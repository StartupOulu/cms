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

### 1. Create the first site

```sh
bin/rails cms:sites:create -- \
  --slug=startupoulu \
  --name="StartupOulu" \
  --repo-url=git@github.com:startupoulu/startupoulu.github.io.git \
  --branch=main \
  --site-url=https://startupoulu.com \
  --publish-author="CMS Bot <cms@startupoulu.com>"
```

This generates an SSH deploy keypair and prints the public half. Add it to the website repo's deploy keys on GitHub (Settings → Deploy keys → Add deploy key, tick **Allow write access**).

Then clone the repo:

```sh
bin/rails cms:sites:create -- --slug=startupoulu ... --clone
```

Or manually:

```sh
GIT_SSH_COMMAND='ssh -i shared/ssh/startupoulu/id_ed25519' \
  git clone git@github.com:startupoulu/startupoulu.github.io.git \
  shared/repos/startupoulu
```

### 2. Create the admin user

```sh
bin/rails console
> user = User.create!(email_address: 'admin@example.com', password: 'strongpassword', display_name: 'Admin')
> Membership.create!(user: user, site: Site.find_by(slug: 'startupoulu'), role: 'admin')
```

### 3. Rails credentials

```sh
bin/rails credentials:edit
```

No CMS-specific credentials are required for M1. Add GitHub tokens or other secrets here as needed.

---

## Running tests

```sh
bin/rails test
```

Tests use SQLite and a real temporary git repository for publish integration tests. No external services required.

---

## License

To be decided before first external contribution. Leaning MIT or Apache 2.0.
