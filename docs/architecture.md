# Architecture

Deep-dive on the CMS internals. AGENTS.md has the overview,
principles, and milestones; this doc holds the architectural detail
that rarely changes.

## Overview

A single CMS instance manages one or more Jekyll website
repositories. Each managed site has its own local clone on disk, its
own deploy key, and its own publish pipeline. Users can be members of
multiple sites with per-site roles (`editor` or `admin`).

Two kinds of repositories are always involved:

1. **CMS repo** — this Rails app.
2. **Website repos** — one or more Jekyll sites (e.g.
   `startupoulu/startupoulu.github.io`). Each is a separate repo.

```
                    ┌──▶ local clone #1 ──▶ GitHub ──▶ site #1
Editor ──▶ CMS ─────┼──▶ local clone #2 ──▶ GitHub ──▶ site #2
                    └──▶ local clone #N ──▶ GitHub ──▶ site #N
```

StartupOulu is the first site served; more sites arrive once the M6
multi-site UI ships.

## Preview

Users must be able to preview posts and events before publishing,
rendered as they will appear on the live site.

**Approach: run Jekyll in each site's clone using `_drafts/`.**

Each site's local clone is already on disk for publishing. The same
clone is used for preview — no separate submodule, no second
checkout.

- Jekyll installed on the CMS server as a runtime dependency.
- A background `jekyll serve --drafts` process runs per site, bound
  to localhost on a site-specific port.
- Rails proxies `/preview/<site-slug>/<draft_id>` to the
  corresponding site's Jekyll server.
- On preview click, the CMS writes the draft to a temp file in that
  site's clone under `_drafts/`, with a unique preview slug.
- Temp files cleaned up after a timeout or on next preview.

Rationale: drift between preview and production is a trust-breaker —
users would stop trusting the preview and manually check the live
site. Running each site's own Jekyll config, layouts, and assets
means preview matches production.

### Constraints

- Never serve preview output on the same path as published content.
- Previews are authenticated-only and scoped to the user's
  membership on the site.
- Sanitize the draft slug before using it as a path component
  (`Open3.capture3` handles shell safety, but path traversal is
  still possible if slugs aren't validated).

## Data model

- Drafts live in SQLite only, never touch Git.
- Every content and audit row carries a `site_id`. Queries scope by
  `Current.site`.
- On publish, the CMS generates Jekyll-formatted files (front matter +
  markdown + media) and commits them to the relevant website repo.
- Editing a published post/event creates a new commit overwriting
  the file.
- Unpublishing creates a commit removing the file.
- Slug changes must delete the old file and create the new one in
  one commit.

### Site

One row per managed website repo. Covers slug, display name, repo
URL, branch, site URL, publish author, clone path, deploy-key path,
and a `content_schema` JSON capturing per-site divergences (filename
patterns, asset paths, event description format). See
`docs/sites.md` for the full field list and console recipes.

### Membership

Join table between `User` and `Site` with a role (`editor` or
`admin`). `Current.site` is resolved from the user's last-selected
site at sign-in; membership is checked on every request that touches
site-scoped content.

### User additions

- `display_name` — string, shown in the header.
- `must_change_password` — boolean. Set `true` when an admin creates
  a user with a temporary password; cleared on the first successful
  password change. See `docs/sites.md` for the console recipe and
  the forced-change flow.
- `current_site_id` — nullable FK to `Site`. The user's last-active
  site, defaulted on next sign-in.
- `last_signed_in_at` — datetime, updated on every sign-in. Displayed
  on the `/users` admin page so admins can see inactive accounts.
- `sign_in_count` — integer, incremented on every sign-in. Also
  shown on the users page.

### Post schema

`Content::Post` is a document-shaped record: a rich body plus a
small set of Jekyll front-matter fields. The body is edited as
`blocks` and serializes to markdown on publish.

Column → front-matter mapping (default `content_schema`):

| Column | Front matter | Type | Notes |
|---|---|---|---|
| `title` | `title` | string | |
| `description` | `description` | text | prose summary used on listings; separate from the body |
| `cover_image` | `blog_image` | string (attachment) | full path in output, e.g. `/assets/images/blogs/<slug>-cover.png` |
| `blocks` | (markdown body) | JSON | editor state; serialized to markdown on publish |
| (constant) | `layout` | `blog` | emitted verbatim by the serializer (per-site override in `content_schema.posts.layout`) |

Inline images used inside `blocks` are committed to the same
`assets/images/blogs/` path and disambiguated by slug + sequential
index (see `Published paths`).

#### Post body states

A `Content::Post` keeps two body copies side by side so that edits
to an already-published post can be autosaved without leaking to the
live site:

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

The non-body columns (`title`, `description`, `cover_image`) follow
the same autosave-vs-snapshot rule via a `published_fields` JSON
column, parallel to events. Autosaves update the live columns; the
published file is only overwritten on explicit `Update`.

### Events schema

Events are structured records, not documents. `Content::Event` has
flat typed columns matching the StartupOulu Jekyll layout's
front-matter fields. No `blocks` JSON, no body content — the
published file's markdown body is empty.

Events follow the same published-state pattern as posts: a
`published_fields` JSON column holds a snapshot of all publishable
column values at publish time, parallel to posts' `published_blocks`.
Autosaves update the live columns; the published file on the site is
only overwritten on explicit `Update`.

Column → front-matter mapping (default `content_schema`):

| Column | Front matter | Type | Notes |
|---|---|---|---|
| `title` | `title` | string | quote when it contains `:`, `&`, `'` |
| `start_time` | `start_time` | datetime | stored UTC, serialized `YYYY-MM-DD HH:MM:SS` without TZ |
| `end_time` | `end_time` | datetime | same |
| `location` | `location` | string | optional |
| `cover_image` | `cover_image` | string | bare filename; the layout prefixes the site's event-assets path |
| `cta_title` | `cta_title` | string | optional; button label |
| `cta_link` | `cta_link` | string (URL) | optional; button href |
| `excerpt` | `excerpt` | text | optional; listing-card summary |
| `description` | `description` | text | paragraph-separated input, serialized to `<br><br>`-joined HTML on publish — the template interpolates `{{ page.description }}` raw |

Per-site variation — different filename patterns, asset paths, or a
markdown-based description format — is captured in
`Site.content_schema`. The default above matches StartupOulu; other
sites override only what they diverge on.

### Published paths

Defaults — overridable per site via `Site.content_schema`:

- Posts: `_posts/YYYY-MM-DD-<slug>.markdown`
- Events: `_events/YYYY-MM-<slug>.html` (month-granularity; day lives
  in `start_time`)
- Blog images: `assets/images/blogs/` (matches the Jekyll blog
  layout's `blog_image` prefix)
- Event images: `assets/images/events/` (matches the Jekyll event
  layout's `cover_image` prefix)

Image filenames are prefixed with the parent post/event's slug to
prevent collisions across content that happens to share similarly
named uploads (e.g. `hero.jpg`). Multiple images in one post are
disambiguated by a sequential index appended to the prefix:
`YYYY-MM-DD-<slug>-1.jpg`, etc. The index is assigned at publish
time in insertion order.

## Git process

The CMS server holds one local clone per managed site. All git
operations shell out via `Open3.capture3` with the site's clone path
as `chdir`.

### Publish flow

1. Acquire the per-site lock (Solid Queue serializes publishes
   within a site; different sites can publish in parallel).
2. `git fetch origin` + `git reset --hard origin/<site.branch>` —
   always start from a clean, up-to-date state.
3. Write files into the working directory (markdown, media, correct
   Jekyll paths and naming).
4. `git add` the changed paths.
5. `git commit` with a message like `Publish: <title>` and the
   site's configured author.
6. `git push origin <site.branch>`.
7. On success, mark the post/event as published. On failure, capture
   stderr, mark the content as publish-failed, surface error to
   user.

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
  chdir: site.clone_path
)
raise PublishError, stderr unless status.success?
```

Never interpolate user input into shell strings. Never use backticks
or `system()` with interpolated content.

### Concurrency

One publish at a time **per site**. Enforced by keying the Solid
Queue publish job on `site_id`. Different sites can publish in
parallel; two publishes to the same site serialize.

### CMS is the sole writer to each website repo

Direct commits to the website branch are technically tolerated — the
`fetch + reset --hard` at the start of every publish pulls them in —
but the CMS assumes it owns each working tree. Don't edit site clones
on the server by hand.

### Deploy keys

- One SSH keypair per site, generated on the server.
- Public half added as a deploy key on the website repo with
  **write** access.
- Private half stored under `shared/ssh/<site-slug>/id_ed25519`.
- `Site.deploy_key_path` records the private-key path; Git uses it
  via a per-repo `core.sshCommand` or a `GIT_SSH_COMMAND` env var
  set by `Site#commit_and_push`.

### Persistence

Every site's local clone must survive restarts. The CMS requires a
persistent disk (Fly.io volume, VPS, or similar). Ephemeral
filesystems (Heroku-style) will not work.

### Initial setup

First install, first site:

1. `bin/setup` installs gems and creates the CMS databases.
2. `bin/rails cms:sites:create -- --slug=... --name=... --repo-url=...
   --branch=... --site-url=... --publish-author=...` generates the
   site's deploy keypair, clones the repo, and prints the public half
   for pasting into GitHub's deploy keys UI.
3. `bin/rails console` to create the first admin user and
   membership. See `docs/sites.md` for the exact console recipe.

No interactive prompt in `bin/setup`, no first-run web wizard, no
ENV-driven seeding. The installer is technical (developer or
operator); the end user is not. Keeping the site and admin bootstrap
out of `bin/setup` keeps it deterministic and idempotent, and keeps
credentials out of shell history.

M6 adds a UI for creating further sites without shell access; the
first site always comes from the console.

## Configuration

Follows the vanilla Rails split between secrets and non-secrets.

**Rails credentials** (`config/credentials.yml.enc`, decrypted with
`master.key`) — CMS-global secrets only:

- GitHub App / token credentials, if added later
- Any third-party API keys

Per-site deploy keys are **files on disk** under
`shared/ssh/<site-slug>/`, not in credentials. Reason: they are
per-site, rotate independently, and already live outside version
control by necessity.

**`config/cms.yml`** — CMS-global non-secret configuration, read via
`Rails.application.config_for(:cms)`. Per-environment sections
(`development`, `test`, `production`). Checked into git.

Keys:

- `name` — wordmark text (e.g. `StartupOulu CMS`)
- `default_locale` — default UI locale (e.g. `fi`)

**Per-site configuration lives on the `Site` row** (repo URL, branch,
content paths, publish author, site URL, clone path, deploy-key path,
`content_schema`). Adding a site never requires a deploy. See
`docs/sites.md` for the full field list.
