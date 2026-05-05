# AGENTS.md

Guidance for AI agents and contributors working on this project.

## Project overview

An open-source CMS for publishing blog posts and events to Jekyll-based
websites via Git. Built primarily for [startupoulu.com](https://startupoulu.com)
but designed to be reusable.

A single CMS instance manages one or more Jekyll websites. Each site
is a separate website repository; a user can be a member of multiple
sites, as an editor or admin. StartupOulu is the first site served;
the CMS is site-agnostic from day one.

The CMS is a friendly wrapper around Git for non-technical users. They
see "Save draft" and "Publish" — never "commit" or "branch". Published
content is committed to the selected site's website repository (e.g.
`startupoulu/startupoulu.github.io`), which GitHub Pages builds and serves.

## Core principles

- **Longevity over features.** Boring, stable stack. Someone should be
  able to pick this up in 2030 and have it boot.
- **Minimal dependencies.** Rails 8 + stdlib. No external gems in v1
  unless there is no reasonable alternative.
- **Git is the source of truth for published content.** If the CMS dies,
  the website survives untouched. Don't let the CMS accumulate state
  that isn't reconstructible from the repo.
- **Generalize from day one.** No hardcoded "startupoulu", and no
  assumed single site. Sites are first-class rows in the database;
  target repo, branch, content paths, and publish author are per-site
  configuration.

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

See `docs/architecture.md` for the architectural detail — the
multi-site setup, preview rendering, data model, publish pipeline,
and configuration split. In short: one CMS instance manages one or
more Jekyll website repos; editor actions become Git commits to the
selected site's repo, and GitHub Pages rebuilds and serves the
site. Per-site membership controls who can edit or administer each
site.

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

## Roadmap

Built in milestones, each one shippable to production on its own. Ship
M1 to startupoulu.com before starting M2. Learn from real use.

### M1 — Publish to Git

**Goal:** an admin can write a blog post and publish it to the live site.

- **Site-aware schema from day one.** `Site`, `Membership`, and
  `site_id` FKs on `Content::Post` and `Audit::Event`. One site
  seeded via console; no site-management UI yet. `Current.site`
  alongside `Current.user`.
- Single content type: `Content::Post`
- Plain markdown editor (textarea only; block editor arrives in M2)
- No drafts, no preview — publish or don't
- Single admin user with a membership on the seeded site, password
  auth (Rails 8 generator)
- Per-site git clone on the server (`shared/repos/<site-slug>/`)
- `post.publish!` renders markdown and commits it to the site's repo; shared Git plumbing lives in a `Content::Publishable` concern (`app/models/concerns/content/publishable.rb`), included by both `Content::Post` and `Content::Event`; low-level `commit_and_push` lives on `Site` since it owns the clone path, deploy key, and branch
- Synchronous publish in the request (2-second wait, no job queue)
- Per-site file lock to serialize concurrent publishes
- `Audit::Event` model logs every publish action, scoped to the site
  and attributed to the acting user via `user_id` (always the single
  admin in M1; M4 surfaces per-user attribution in the UI).
  Namespaced to avoid collision with the `Content::Event` model
  added in M4.
- Nginx + Certbot + Puma via systemd
- README with setup walkthrough, including console recipes to create
  the first site and admin

**Done when:** a post written in the CMS appears on startupoulu.com
within a minute.

### M2 — Drafts, block editor, and image upload

**Goal:** editors write comfortably with a proper editor and save work
in progress.

- `Content::Post` gains `draft` / `published` states
- `Content::Post` gains first-class non-body columns: `description`
  (prose summary → `description:` front matter) and `cover_image`
  (Active Storage attachment → `blog_image:` front matter). See
  `docs/architecture.md` → Post schema.
- Two-body snapshot on `Content::Post`: `blocks` (autosaved) +
  `published_blocks` (site snapshot), plus `published_fields` JSON
  for the non-body columns, so autosave never leaks to the live
  site. See `docs/architecture.md` → Post body states.
- Custom block-based markdown editor replaces the textarea (see
  `docs/ui.md`)
- Active Storage for images — cover image plus inline body images
- Drag-and-drop and paste-to-upload via a Stimulus controller
- Images commit to `assets/images/blogs/` in the website repo on
  publish
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
- Rails proxies `/preview/<site-slug>/<post_id>` to that site's
  local Jekyll server
- Authenticated-only; preview URLs never leak drafts publicly
- Slug validation to prevent path traversal

**Done when:** clicking "Preview" shows the draft rendered with the
real site layout and CSS.

### M4 — Events and multi-user within a site

**Goal:** second content type and more than one person using the
CMS. Still single-site operationally; multi-site management UI
arrives in M6.

- `Content::Event` content type: title, start/end datetime, location,
  cover image, summary (excerpt), description, call-to-action
  (title + link). Stored as flat typed columns — **not** the block
  editor. See `docs/architecture.md` → Events schema for the
  front-matter mapping.
- Separate `EventsController` and a form-based editor view with
  native datetime pickers. No block editor for events.
- Timezone handling (store UTC, display in Europe/Helsinki)
- Events inherit the M2 publish machinery (unpublish,
  edit-after-publish, slug rename) and a `published_fields` JSON
  snapshot parallel to posts' `published_blocks`. The M2 image
  pipeline extends to the event cover-image slot
  (`assets/images/events/`). M3 preview extends to events at
  `/preview/<site-slug>/<event_id>`.
- **Admin creates users and memberships via Rails console** with a
  temporary password. New users land on a forced-password-change
  screen at first sign-in (`User.must_change_password` flag, cleared
  after a successful change). No email sending (see `docs/ui.md`
  sign-in section). Membership management UI arrives in M6.
- Audit entries render the acting user's `display_name` (the
  `user_id` column is already on `Audit::Event` from M1).

**Done when:** the StartupOulu team is using the CMS for both blog
posts and event announcements, with more than one person publishing.

### M5 — Activity dashboard

**Goal:** small team coordinates through the CMS instead of asking
each other on Slack.

- Dashboard at `/` showing recent `Audit::Event` entries for the
  current site
- "Who published what, and when" feed, attributed via the `user_id`
  already on `Audit::Event`
- Publish-failure surfacing: a persistent dashboard banner when a
  publish errored, until an admin acknowledges it (M1 already shows
  the inline editor error; this is the team-level surface)

**Done when:** someone visits `/` and sees "Maria published *Foo* 2
hours ago" and feels oriented.

### M6 — Multi-site management

**Goal:** admins can add, configure, and switch between multiple
sites from the UI, without shell access.

- Site switcher in the header — dropdown showing the user's sites,
  defaulting to the last-used site (per-user session)
- Admin UI to add a site: repo URL, branch, content paths, publish
  author, site URL
- Per-site deploy-key generation at site-add time; CMS writes the
  keypair to `shared/ssh/<site-slug>/`, displays the public half
  once so an admin can paste it into the website repo's deploy keys
- Admin UI to manage memberships per site (add/remove editors,
  promote/demote)
- Per-site clone bootstrap via background job triggered from the
  add-site form
- First-site-on-install bootstrap remains the console recipe — no
  install wizard

**Done when:** a second Jekyll site can be added and published to
from the UI without touching the server shell (beyond the initial
CMS install).

### Explicitly deferred beyond M6

Scheduled publishing, version history UI beyond git log, comments,
analytics, newsletters, approval workflows, taxonomies/categories
beyond simple tags, video upload (embed YouTube for now), GitHub
Pages build-status polling.

## Scope discipline

- Don't build M2 features into M1. The bar for M1 is "it works on the
  real site."
- Every milestone should be deployed before the next begins.
- If a milestone is taking longer than ~a month of weekends, it's too
  big — split it. Known candidates: M2 (drafts can ship without the
  block editor; images can be their own step) and M4 (events can
  ship without the multi-user auth flow).
- Say no to features that don't fit the current milestone, even good
  ones. Write them down for later.

**Out (explicitly deferred):**

- Roles beyond editor/admin
- Scheduled publishing
- Version history UI (Git has it; no UI for v1)
- Comments, analytics, newsletters

## Security

- All secrets in Rails credentials (see `docs/architecture.md`). Never
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
- **No service objects — ever.** Don't create `app/services/` or any
  class named `*Service`, `*Form`, `*Query`, `*Decorator`, or
  `*Presenter`. These patterns exist because people don't trust their
  models; trust your models. If behavior spans multiple models, it
  belongs in a concern. If a method is growing long, extract private
  methods or a well-named concern — not a new plain Ruby object.
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

See `docs/deployment.md` for the full walkthrough: first-time setup
checklist, server architecture, Nginx / Puma / systemd configs,
deploy script, and operational notes. No Docker, no Kamal, no
containers — just `rsync` to a Linux server with Nginx, Puma,
SQLite, Certbot, and systemd.

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
- Never create service objects, form objects, query objects, decorators,
  or presenters. No `app/services/`, no `*Service`, no `*Form`, no
  `*Query`. Put logic in models; extract shared behavior into concerns.
- Don't hardcode "startupoulu", and don't assume a single site. Use
  the `Site` model; scope queries by `Current.site`.
- Don't interpolate user input into shell commands — use `Open3.capture3`
  with separate arguments.
- Don't let the CMS hold state that can't be reconstructed from the
  Git repos and the drafts in SQLite.
- Keep the publish pipeline well-tested. It's the scary part.
- When in doubt, choose the boring option.