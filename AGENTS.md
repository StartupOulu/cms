# AGENTS.md

Guidance for AI agents and contributors working on this project.

## Project overview

An open-source CMS for publishing blog posts and events to Jekyll-based
websites via Git. Built primarily for [startupoulu.com](https://startupoulu.com)
but designed to be reusable.

The CMS is a friendly wrapper around Git for non-technical users. They
see "Save draft" and "Publish" — never "commit" or "branch". Published
content is committed to a separate website repository (e.g.
`startupoulu/startupoulu.github.io`), which GitHub Pages builds and serves.

## Core principles

- **Longevity over features.** Boring, stable stack. Someone should be
  able to pick this up in 2030 and have it boot.
- **Minimal dependencies.** Rails 8 + stdlib. No external gems in v1
  unless there is no reasonable alternative.
- **Git is the source of truth for published content.** If the CMS dies,
  the website survives untouched. Don't let the CMS accumulate state
  that isn't reconstructible from the repo.
- **Generalize from day one.** No hardcoded "startupoulu". Target repo,
  branch, and content paths are configuration.

## Stack

- Ruby on Rails 8
- SQLite3
- Solid Queue (ships with Rails 8) for background jobs
- Active Storage for media (ships with Rails)
- Rails 8 built-in authentication generator (`bin/rails generate authentication`)
- Rails credentials for secrets
- `Open3` (stdlib) for shelling out to `git` and `jekyll`
- Custom block-based markdown editor (vanilla JS + Stimulus, no
  third-party editor library). See `docs/ui.md`.
- Jekyll as a runtime dependency (for rendering previews against the
  website submodule)

External Ruby gems beyond what Rails itself brings: `rails-i18n`
(accepted carve-out — see `docs/ui.md`). No other additions. Jekyll
runs as an external command via `Open3`, not as a Rails dependency.

## Architecture

Two repositories:

1. **CMS repo** — this Rails app
2. **Website repo** — e.g. `startupoulu/startupoulu.github.io`, a Jekyll site

The CMS server has a local clone of the website repo on disk. Publishing
writes files into that clone, commits, and pushes to GitHub via a deploy
key. GitHub Pages rebuilds and serves the site.

```
Editor → CMS (Rails) → local repo clone → GitHub → GitHub Pages
```

## Frontend constraints

Visual direction and interaction patterns live in `docs/ui.md`. The
UI is bilingual (Finnish default, English toggle) and content is
English-only. This section covers the tech constraints only.

**No CSS frameworks.** No Tailwind, no Bootstrap, no Bulma, no utility
libraries of any kind. Use vanilla CSS with modern features:

- CSS custom properties (variables) for theming — define once in
  `:root`, reference everywhere
- `@layer` for cascade control
- Logical properties (`margin-inline`, `padding-block`)
- `oklch()` for colors (better perceptual uniformity than hex/rgb)
- Container queries where they make sense
- `:has()` and other modern selectors
- Dark mode is out of scope for M1–M3 (see `docs/ui.md`)

Follow Fizzy's pattern: one file per component/concern in
`app/assets/stylesheets/`, served by Propshaft.

**No JavaScript libraries except Hotwire.** Allowed:

- Turbo
- Stimulus

Not allowed: React, Vue, Alpine, jQuery, Lodash, Moment, anything else.

**No third-party editor library.** The CMS ships a custom
block-based markdown editor built with vanilla JS and Stimulus. Each
block is one markdown primitive (heading, paragraph, list, image,
quote, code). See `docs/ui.md` for the block set, interaction model,
and v1 scope (no inline formatting in the first release).

Rationale: markdown's top-level syntax *is* blocks, so the impedance
match is clean and the serializer is trivial. The custom editor
avoids a large JS dependency, keeps Importmap + Propshaft honest,
and keeps storage as structured JSON that round-trips to markdown
losslessly.

**Build tooling:** Importmap + Propshaft. No Node, no npm, no Webpack,
no esbuild. The editor stays within this constraint.

## Preview feature

Users must be able to preview events and blog posts before publishing,
rendered as they will appear on the live site.

### Approach: include the website repo as a Git submodule

The CMS repo includes `startupoulu/startupoulu.github.io` as a submodule
at `vendor/site/` (or similar). This gives the CMS access to the
Jekyll site's layouts, includes, CSS, and config without duplicating
them.

### Preview rendering

**Approach: run Jekyll in the CMS (fidelity over speed).**

Jekyll is a runtime dependency of the CMS server. Document it in the
README and install it via the setup script (`bin/setup`).

- On preview request, write the draft's rendered markdown to a temp
  location inside the submodule's `_posts/` or `_events/`
- Run `jekyll build` against the submodule via `Open3.capture3`
- Serve the resulting HTML in an iframe or new tab
- Clean up temp files after a timeout or on next preview

Rationale: drift between preview and production is a trust-breaker —
users would stop trusting the preview and manually check the live site,
which defeats the purpose. A few seconds of build time is an acceptable
trade.

### Preview flow

1. User clicks "Preview" in the draft editor
2. CMS writes the draft to a temp file inside the submodule's content
   directory with a unique preview slug
3. CMS runs `jekyll build --destination tmp/preview/<draft_id>/` via
   `Open3.capture3`
4. CMS serves the built HTML at `/preview/<draft_id>/...`
5. Temp files cleaned up after a timeout or on next preview

### Submodule management

- Pin the submodule to a specific commit in the CMS repo — don't
  auto-update. Preview should match the *published* site, not whatever
  is currently on `main`.
- A rake task `bin/rails cms:update_site_submodule` pulls the latest
  commit from the site repo when an admin wants to refresh.
- After a successful publish, the CMS can automatically bump the
  submodule to the commit it just pushed — keeps previews in sync with
  reality.

### Constraints

- Never serve preview output on the same path as published content
- Previews are authenticated-only; don't let them leak drafts publicly
- Sanitize the draft slug before using it as a path component
  (`Open3.capture3` handles shell safety, but path traversal is still
  possible if slugs aren't validated)

## Roadmap

Built in milestones, each one shippable to production on its own. Ship
M1 to startupoulu.com before starting M2. Learn from real use.

### M1 — Publish to Git

**Goal:** an admin can write a blog post and publish it to the live site.

- Single content type: `Content::Post`
- Plain markdown editor (textarea only; block editor arrives in M2)
- No drafts, no preview — publish or don't
- Single admin user, password auth (Rails 8 generator)
- Local git clone of the website repo on the server
- `PublishService` writes markdown to `_posts/`, commits, pushes
- Synchronous publish in the request (2-second wait, no job queue)
- File lock to serialize concurrent publishes
- `Audit::Event` model logs every publish action (namespaced to avoid
  collision with the `Content::Event` model added in M4)
- Nginx + Certbot + Puma via systemd
- README with setup walkthrough

**Done when:** a post written in the CMS appears on startupoulu.com
within a minute.

### M2 — Drafts, block editor, and image upload

**Goal:** editors write comfortably with a proper editor and save work
in progress.

- `Content::Post` gains `draft` / `published` states
- Custom block-based markdown editor replaces the textarea (see
  `docs/ui.md`)
- Active Storage for images
- Drag-and-drop and paste-to-upload via a Stimulus controller
- Images commit to `assets/` in the website repo on publish
- Unpublish action (new commit removing the file)
- Edit published content (new commit overwriting)
- Slug rename handles old-file deletion in the same commit

**Done when:** an editor can write a draft over multiple sessions,
drop in screenshots, publish, edit later.

### M3 — Preview

**Goal:** editors see what their post will look like before publishing.

- Jekyll installed on the CMS server as a runtime dependency
- `_drafts/` directory used in the existing website repo clone (no
  separate submodule)
- `jekyll serve --drafts` as a background systemd service on localhost
- Rails proxies `/preview/<post_id>` to the local Jekyll server
- Authenticated-only; preview URLs never leak drafts publicly
- Slug validation to prevent path traversal

**Done when:** clicking "Preview" shows the draft rendered with the
real site layout and CSS.

### M4 — Events and multi-user

**Goal:** second content type and more than one person using the CMS.

- `Content::Event` content type: title, start/end datetime, location,
  description, hero image, RSVP link
- Separate `EventsController` and editor view with date pickers
- Timezone handling (store UTC, display in Europe/Helsinki)
- Multi-user: `editor` and `admin` roles
- Admin invites editors by email
- Per-user attribution on `Audit::Event` entries

**Done when:** the StartupOulu team is using the CMS for both blog
posts and event announcements, with more than one person publishing.

### M5 — Activity dashboard and polish

**Goal:** small team coordinates through the CMS instead of asking
each other on Slack.

- Dashboard at `/` showing recent `Audit::Event` entries
- "Who published what, and when" feed
- Publish failure surfacing (if `git push` fails, the error shown in
  the dashboard until acknowledged)
- GitHub Pages build status polling — mark a publish as "live" only
  after the Pages build succeeds
- Basic search over posts and events

**Done when:** someone visits `/` and sees "Maria published *Foo* 2
hours ago" and feels oriented.

### Explicitly deferred beyond M5

Scheduled publishing, version history UI beyond git log, comments,
analytics, newsletters, multi-site configuration, approval workflows,
taxonomies/categories beyond simple tags, video upload (embed YouTube
for now).

## Scope discipline

- Don't build M2 features into M1. The bar for M1 is "it works on the
  real site."
- Every milestone should be deployed before the next begins.
- If a milestone is taking longer than ~a month of weekends, it's too
  big — split it.
- Say no to features that don't fit the current milestone, even good
  ones. Write them down for later.

**Out (explicitly deferred):**

- Roles beyond editor/admin
- Scheduled publishing
- Version history UI (Git has it; no UI for v1)
- Multi-site configuration
- Comments, analytics, newsletters

## Data model notes

- Drafts live in SQLite only, never touch Git.
- On publish, the CMS generates Jekyll-formatted files (front matter +
  markdown + media) and commits them to the website repo.
- Editing a published post creates a new commit overwriting the file.
- Unpublishing creates a commit removing the file.
- Slug changes must delete the old file and create the new one in one
  commit.

### Post body states

A `Content::Post` keeps two bodies side by side so that edits to a
published post can be autosaved without leaking to the live site:

- `blocks` (JSON) — the current editor state. Always written by
  autosave. Source of truth for what the editor shows.
- `published_blocks` (JSON, nullable) — snapshot of what's on the
  site as of the last publish. `NULL` for posts that have never been
  published.

Derived states:

- **Draft (never published):** `published_at` is `NULL`,
  `published_blocks` is `NULL`. Only `blocks` matters.
- **Published, no pending edits:** `published_blocks == blocks`. The
  `Publish` / `Update` button is disabled — there's nothing to push.
- **Published with pending edits:** `published_blocks` differs from
  `blocks`. The `Update` button is active. Clicking it copies
  `blocks` → `published_blocks` and commits the serialized markdown
  to Git.

This keeps the editor stateful across sessions without complicating
the on-disk markdown.

### Published paths

In the website repo:

- Posts: `_posts/YYYY-MM-DD-<slug>.md`
- Events (M4): `_events/YYYY-MM-DD-<slug>.md` (or the site's
  collection convention)
- Media:
  - Blog images: `assets/blog/` subfolder
  - Event images: `assets/events/` subfolder
  - Image filenames are prefixed with `YYYY-MM-DD-<slug>` (matching
    the parent post's Jekyll filename) to prevent collisions across
    posts that happen to share similarly-named uploads (e.g.
    `hero.jpg`).
  - Multiple images within the same post are disambiguated by a
    sequential index appended to the prefix:
    `YYYY-MM-DD-<slug>-1.jpg`, `YYYY-MM-DD-<slug>-2.jpg`, etc. The
    index is assigned at publish time in insertion order.

## Git process

The CMS server holds a local clone of the website repo. All git
operations shell out via `Open3.capture3` with the repo path as `chdir`.

### Publish flow

1. Acquire lock (Solid Queue single worker serializes publishes).
2. `git fetch origin` + `git reset --hard origin/main` — always start
   from a clean, up-to-date state.
3. Write files into the working directory (markdown, media, correct
   Jekyll paths and naming like `_posts/YYYY-MM-DD-slug.md`).
4. `git add` the changed paths.
5. `git commit` with a message like `Publish: <title>` and a configured
   author.
6. `git push origin main`.
7. On success, mark the post as published. On failure, capture stderr,
   mark the post as publish-failed, surface error to user.

### Why `Open3.capture3`

- Returns stdout, stderr, and exit status separately — needed for
  surfacing git errors to users.
- `chdir:` option runs in the repo path without changing the Rails
  process cwd.
- Arguments passed as separate strings — no shell, no injection risk
  even with user-supplied content like post titles.

Example:

```ruby
stdout, stderr, status = Open3.capture3(
  "git", "commit", "-m", "Publish: #{post.title}",
  chdir: repo_path
)
raise PublishError, stderr unless status.success?
```

Never interpolate user input into shell strings. Never use backticks or
`system()` with interpolated content.

### Concurrency

One publish at a time. Enforced by running Solid Queue with a single
worker for the publish queue. Prevents working-directory races.

### CMS is the sole writer to the website repo

Document this clearly. Direct commits to `main` are technically tolerated
because `fetch + reset --hard` before each publish pulls them in, but
the CMS assumes it owns the working tree. Don't edit the local clone
manually on the server.

### Deploy key

- SSH keypair generated on the server.
- Public half added to the website repo as a deploy key with **write**
  access.
- Private half referenced by `~/.ssh/config` for the CMS user.
- Document the setup in the README.

### Persistence

The local repo clone must survive restarts. Requires a persistent disk:
Fly.io with a volume, a VPS, or similar. Ephemeral filesystems
(Heroku-style) will not work for v1.

### Initial setup

A rake task clones the website repo on first boot:

```
bin/rails cms:setup
```

The first admin user is created **manually** via the Rails console
after install — no interactive prompt in `bin/setup`, no first-run
web wizard, no ENV-driven seeding. The README documents this step:

```
bin/rails console
> User.create!(email: "…", password: "…", display_name: "…")
```

Rationale: the installer is technical (developer or operator); the
end user is not. Keeping the admin bootstrap out of `bin/setup` means
`bin/setup` stays deterministic and idempotent, and credentials are
never captured in shell history or an env file.

## Configuration

Follows the vanilla Rails split between secrets and non-secrets.

**Rails credentials** (`config/credentials.yml.enc`, decrypted with
`master.key`) — secrets only:

- SSH deploy key path (or contents)
- GitHub App / token credentials if added later
- Any third-party API keys

**`config/cms.yml`** — non-secret configuration, read via
`Rails.application.config_for(:cms)`. Per-environment sections
(`development`, `test`, `production`). Checked into git.

Keys include:

- `name` — wordmark text (e.g. `StartupOulu CMS`)
- `target_repo` — website repo URL / local clone path
- `target_branch` — the branch that GitHub Pages serves (usually
  `main`)
- `content_paths` — where to write posts, events, assets inside the
  website repo
- `publish_author` — git author name/email used for publish commits
- `site_url` — base URL of the public site, used for URL previews
  and `View on site` links

Read config at boot; expose it via a small `CMS.config` (or similar)
singleton so app code doesn't pass a hash around.

## Security

- All secrets in Rails credentials (see `Configuration` above). Never
  in `.env`, never in `config/cms.yml`, never committed.
- Admin panel is internet-facing: enforce HTTPS, strong passwords.
- Never commit credentials, deploy keys, or `.env` files.
- Editor stores structured block JSON in SQLite; serialize to
  markdown at publish time. Sanitize any raw-text paste input before
  storing.
- Sessions are 14-day rolling cookies (refreshed on each request).
  See `docs/ui.md` for the UX rationale.

## Reference projects

Look at these for inspiration, patterns, and examples of minimal-gem
Rails apps:

- **Fizzy** — https://github.com/basecamp/fizzy
- **once-campfire** (Campfire) — https://github.com/basecamp/once-campfire

Both are Basecamp/37signals projects following the same philosophy we're
aiming for: Rails-first, minimal dependencies, boring stack, SQLite,
built to last. Worth studying before introducing new patterns or gems.

## Conventions from Fizzy and Campfire

Adopted from their AGENTS.md, STYLE.md, Gemfiles, and overall structure.
The guiding line from DHH/37signals: **"Vanilla Rails is plenty."**

### Stack choices

- **Rails edge or latest stable.** One major framework dependency, kept
  current.
- **SQLite in production.** Use WAL mode and IMMEDIATE transactions
  (Rails 8 defaults handle this).
- **Multiple SQLite databases** for separation of concerns:
  `storage/production.sqlite3` (primary), `cache.sqlite3`,
  `queue.sqlite3`. Lets writes happen in parallel across files.
- **Solid Queue** for background jobs. No Redis, no Sidekiq.
- **Solid Cache** for caching. No Memcached.
- **Solid Cable** if you need WebSockets later.
- **Propshaft + Importmap + Stimulus + Turbo** for front end. No Node,
  no bundler, no Webpack, no Tailwind.
- **Vanilla CSS.** No Sass, no PostCSS. Modern CSS (custom properties,
  `oklch()`, `@layer`) is enough.
- **Puma** as the web server. **Thruster** in front for HTTP/2, caching,
  compression.
- **Bootsnap** for boot speed.

### Coding style (from Fizzy's STYLE.md)

- **Clarity over cleverness.** Code should read pleasantly.
- **Prefer expanded conditionals over guard clauses** when the method
  body is non-trivial. Guard clauses are for short early returns; they
  hide the main flow when the body is complex.
- **Order methods vertically by invocation order.** When reading
  top-to-bottom, you follow the call chain. Public methods first, then
  private helpers in the order they're called.
- **Bang methods (`!`) only when paired with a non-bang counterpart.**
  Don't use `!` just to signal "this mutates" or "this is dangerous."
- **Fat models, thin controllers.** Domain logic lives in models.
  Controllers orchestrate; they don't compute.
- **RESTful controllers.** Seven actions (index, show, new, create,
  edit, update, destroy). If you need a new verb, usually you need a
  new controller. E.g. `ReactionsController#destroy` beats
  `CommentsController#remove_reaction`.
- **Consistent controller patterns.** `before_action :set_record` and
  `before_action :ensure_permission_to_*` callbacks. Destroy actions
  become one line. When a pattern emerges, update older code to match.
- **Concerns for cross-cutting model behavior.** Each concern is a
  small, named mixin in `app/models/concerns/`.
- **Namespace models when it clarifies intent or avoids collisions.**
  `Content::Post`, `Content::Event`, `Audit::Event`. Prefer namespacing
  over picking an awkward alternate name. Namespaces live in
  subdirectories: `app/models/content/post.rb`,
  `app/models/audit/event.rb`. Controllers follow the same convention:
  `Content::PostsController` in `app/controllers/content/posts_controller.rb`.
- **`Current` attributes** for per-request context (current user,
  account, etc.) — `app/models/current.rb`. Don't pass these through
  every method.
- **Minitest, not RSpec.** Fixtures, not factories. System tests with
  Capybara + Selenium for the full stack.
- **Barely any logging in models.** Let Rails log. Don't litter code
  with `Rails.logger.info`.
- **Concise commit messages.** Focus on *what*, kept short. Not every
  commit needs a novel.

### Project structure

- `bin/setup` — one command for a fresh developer. Installs gems, creates
  DB, loads schema and fixtures. A contributor should be able to clone
  and run `bin/setup && bin/dev` and have a working app.
- `bin/dev` — starts the dev server (and jobs, and any other processes)
  via `foreman` or `Procfile.dev`.
- `bin/ci` — runs the full CI suite locally: style, security, tests.
  Same thing CI runs.
- `bin/jobs` — manages Solid Queue workers.
- `app/models/concerns/` — extracted, named behaviors.
- `app/models/current.rb` — per-request globals done properly.
- `config/recurring.yml` — scheduled jobs, Solid Queue's cron.
- `storage/` — SQLite databases and Active Storage files. Persistent
  volume target in production.
- `docs/` — human-written development, deployment, and architecture
  docs. Not just a README.

### Development experience

- **Passwordless magic-link auth in dev.** Or print the verification
  code to the Rails console. Don't make contributors invent passwords.
- **Fixtures seed a usable dev environment.** A known user, some
  content, enough to click around on first boot.
- **Dev uses the same DB engine as production.** Both SQLite. No
  surprises when deploying.

### Deployment

Follows the approach described in Tuomas Jomppanen's
["Manually deploy Ruby on Rails 8 application to Linux server"](https://www.jomppanen.com/2024/11/20/manually-deploy-ruby-on-rails-8-application-to-linux-server.html).
No Docker, no Kamal, no containers. Just you and your Linux server.

#### Architecture on the server

```
Firewall → Nginx (TLS + static assets) → Puma (Unix socket) → Rails app
                                                              → SQLite
```

Nginx handles HTTPS, serves `public/assets` directly, and proxies
everything else to Puma over a Unix socket. Let's Encrypt via Certbot
keeps TLS certificates current.

#### Server prerequisites

- Ubuntu Linux (24.04 LTS recommended)
- `deploy` user with SSH public-key auth and passwordless sudo
- Ruby installed via rbenv under the `deploy` user
- Bundler, Git, SQLite3, Nginx, Certbot, Jekyll
- Firewall configured (UFW) allowing HTTP/HTTPS/SSH

Install packages:

```
sudo apt update
sudo apt install -y curl git-core nginx sqlite3 libsqlite3-dev \
  build-essential libffi-dev libyaml-dev zlib1g-dev pkg-config
```

Ruby via rbenv, Bundler via `gem install bundler`, Jekyll via
`gem install jekyll`.

#### Directory structure

```
/var/www/apps/<app_name>/
├── current -> releases/<timestamp>   # symlink to latest deploy
├── logs/                             # Puma stdout/stderr logs
├── releases/                         # timestamped deploy directories
│   ├── 2026-04-16-14-30-00/
│   └── 2026-04-17-09-15-22/
├── shared/
│   ├── storage/                      # SQLite databases + Active Storage
│   └── master.key                    # Rails credentials key
├── repo/                             # local clone of the website repo
│                                     # (used by PublishService and preview)
└── tmp/
    ├── pids/
    └── sockets/                      # Puma socket file
```

- `current/` always points to the latest release via symlink
- `shared/storage/` persists between deploys — symlinked into each
  release
- `shared/master.key` copied once, symlinked into each release's
  `config/`
- `repo/` holds the website repository clone (for publish and preview)

#### Puma configuration

Puma communicates with Nginx via Unix socket. Runs Solid Queue
in-process via the `solid_queue` plugin for single-server deployments.

```ruby
# config/puma.rb
if ENV.fetch("RAILS_ENV", nil) == "production"
  app_dir = ENV.fetch("APP_DIR", "/var/www/apps/startupoulu-cms")

  environment "production"
  directory "#{app_dir}/current"

  bind "unix://#{app_dir}/tmp/sockets/puma.sock"
  pidfile "#{app_dir}/tmp/pids/puma.pid"
  state_path "#{app_dir}/tmp/pids/puma.state"

  stdout_redirect "#{app_dir}/logs/puma.stdout.log",
                  "#{app_dir}/logs/puma.stderr.log",
                  true

  preload_app!
  workers ENV.fetch("WEB_CONCURRENCY", 2)

  plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]
end

threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count
port ENV.fetch("PORT", 3000)
```

#### Nginx virtual host

```nginx
upstream rails_app {
  server unix:///var/www/apps/startupoulu-cms/tmp/sockets/puma.sock
         fail_timeout=0;
}

server {
  server_name cms.startupoulu.com;
  root /var/www/apps/startupoulu-cms/current/public;

  location ^~ /assets/ {
    gzip_static on;
    expires max;
    add_header Cache-Control public;
  }

  location = /favicon.ico { access_log off; log_not_found off; }
  location = /robots.txt  { access_log off; log_not_found off; }

  location / {
    proxy_pass http://rails_app;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $http_host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_redirect off;

    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
  }
}
```

Certbot adds the TLS directives automatically:
`sudo certbot --nginx -d cms.startupoulu.com`

#### Systemd service

```ini
# /etc/systemd/system/startupoulu-cms.service
[Unit]
Description=StartupOulu CMS (Puma)
After=network.target

[Service]
Type=simple
User=deploy
WorkingDirectory=/var/www/apps/startupoulu-cms/current
Environment=RAILS_ENV=production
Environment=SOLID_QUEUE_IN_PUMA=true
ExecStart=/home/deploy/.rbenv/shims/bundle exec puma -C config/puma.rb
Restart=always

[Install]
WantedBy=multi-user.target
```

Enable and start:

```
sudo systemctl enable --now startupoulu-cms
```

#### Deploy script (`bin/deploy`)

Lives in the CMS repo. Run from local dev: `bin/deploy`.

Core steps:

1. Generate a timestamped release directory name
2. `rsync` the app to the server (excluding `.git`, `storage/`,
   `tmp/`, `test/`, credentials keys, sqlite files)
3. Symlink `shared/master.key` into `config/master.key`
4. Symlink `shared/storage/` into `storage/`
5. `bundle install` on the server
6. `RAILS_ENV=production bin/rails db:migrate`
7. `RAILS_ENV=production bin/rails assets:precompile`
8. Update the `current` symlink to point to the new release
9. `sudo systemctl restart startupoulu-cms`

Rollback = point `current` symlink at the previous release directory
and restart.

#### Operational notes

- **Log rotation:** configure logrotate for Puma and Nginx logs, or
  the disk fills up
- **Backups:** back up `shared/storage/` regularly (SQLite DBs +
  uploads). Follow the 3-2-1 rule. Consider Litestream for continuous
  SQLite replication to object storage.
- **Monitoring:** `rails_performance` gem or simple uptime checks
- **The deploy script bypasses version control** — always commit and
  push before deploying. The deploy copies your local working tree,
  not a git ref.

### Dependencies philosophy

- **Add a gem only when the alternative is clearly worse.** Every gem
  is a long-term maintenance commitment.
- **Prefer stdlib and Rails built-ins.** `Open3`, `Net::HTTP`, `JSON`,
  `FileUtils`, Active Storage, Active Job, Action Mailer — all already
  there.
- **If a gem is needed, prefer ones maintained by the Rails core team
  or 37signals.** They share the longevity philosophy.
- **`require: false` for gems only used in specific places** (e.g.
  `bootsnap`). Keeps boot fast.

### Documentation for contributors

- Top-level `README.md` — what it is, how to install, how to deploy.
- `AGENTS.md` — this file, for AI agents and contributors.
- `STYLE.md` — coding style, linked from AGENTS.md with `@STYLE.md`.
- `docs/development.md` — local dev setup, env vars, gotchas.
- `docs/deployment.md` — production deployment walkthrough.
- `docs/ui.md` — visual direction, interaction patterns, per-screen
  primary actions, UI-language policy.
- Release notes in GitHub Releases, with short bullet-point changelogs
  crediting contributors.

### License

- Fizzy uses the O'Saasy License (non-standard, SaaS-restricted).
- Campfire is sold commercially and not OSS-licensed in the usual sense.
- **For us: stick with MIT or Apache 2.0.** We want maximum reuse and
  community contribution, not SaaS protection.

## License

To be decided before first external contribution. Leaning MIT or
Apache 2.0.

## Conventions for AI agents

- Don't add gems unless necessary. Prefer stdlib and Rails built-ins.
- Don't hardcode "startupoulu" anywhere. Use configuration.
- Don't interpolate user input into shell commands — use `Open3.capture3`
  with separate arguments.
- Don't let the CMS hold state that can't be reconstructed from the Git
  repo and the drafts in SQLite.
- Keep the publish pipeline well-tested. It's the scary part.
- When in doubt, choose the boring option.