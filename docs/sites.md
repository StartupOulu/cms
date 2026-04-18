# Sites and memberships

Per-site data model, provisioning, and admin recipes. Complements
`docs/architecture.md` (server topology) and `AGENTS.md` (milestone
scope).

## Data model

### `Site`

One row per managed Jekyll website. Created via console in M1–M5;
via the admin UI in M6+.

| Column | Type | Notes |
|---|---|---|
| `slug` | string, unique | used in `shared/repos/<slug>/`, deploy-key filenames, preview URLs |
| `name` | string | display name, e.g. "StartupOulu" |
| `repo_url` | string | git URL, e.g. `git@github.com:startupoulu/startupoulu.github.io.git` |
| `branch` | string | branch GitHub Pages serves; usually `main` |
| `site_url` | string | public base URL, e.g. `https://startupoulu.com`, for "View on site" links |
| `publish_author_name` | string | git author name for publish commits |
| `publish_author_email` | string | git author email for publish commits |
| `clone_path` | string | absolute path to the local clone on the server |
| `deploy_key_path` | string | absolute path to the site's private SSH key |
| `content_schema` | JSON, nullable | per-site overrides; `NULL` means inherit the default |

**`content_schema`** captures the parts of the Jekyll site that
differ between deployments: event front-matter field names, filename
patterns, asset paths. Default matches StartupOulu:

```json
{
  "posts": {
    "filename": "_posts/%Y-%m-%d-<slug>.markdown",
    "layout": "blog",
    "assets_path": "assets/images/blogs/",
    "cover_field": "blog_image",
    "permalink": "/%Y/%m/%d/<slug>.html"
  },
  "events": {
    "filename": "_events/%Y-%m-<slug>.html",
    "layout": "event",
    "assets_path": "assets/images/events/",
    "cover_field": "cover_image",
    "description_format": "html_paragraphs"
  }
}
```

Only sites that diverge from the default populate this field; all
others inherit.

### `Membership`

User ↔ Site, with a role.

| Column | Type | Notes |
|---|---|---|
| `user_id` | FK | |
| `site_id` | FK | |
| `role` | enum | `editor` or `admin` |

Unique index on `(user_id, site_id)`.

### `User` additions

| Column | Type | Notes |
|---|---|---|
| `must_change_password` | boolean, default `false` | set `true` when an admin creates a user with a temp password; cleared on first successful password change |
| `current_site_id` | FK, nullable | last-selected site; defaults the next sign-in's site context |

## Site switcher UX

See `docs/ui.md` → Header → Site switcher.

## Forced password change

- On sign-in, if `user.must_change_password` is true, redirect to
  `/account/password` before the app home.
- The form requires current password + new password + new-password
  confirmation.
- On success, clear the flag and redirect to the user's default
  site home.
- No other screens are reachable while the flag is set; the sign-out
  link remains available.

## Console recipes

These are intended for operators. Before M6, they are the only way
to add sites and users.

### Create the first site

```
bin/rails cms:sites:create -- \
  --slug=startupoulu \
  --name="StartupOulu" \
  --repo-url=git@github.com:startupoulu/startupoulu.github.io.git \
  --branch=main \
  --site-url=https://startupoulu.com \
  --publish-author="CMS <cms@startupoulu.com>"
```

The rake task generates the SSH keypair under `shared/ssh/<slug>/`,
clones the repo into `shared/repos/<slug>/`, and prints the public
key for pasting into GitHub's deploy-keys UI.

### Create the first admin

```
bin/rails console
> site = Site.find_by!(slug: "startupoulu")
> user = User.create!(
    email: "maria@example.com",
    password: SecureRandom.urlsafe_base64(12),
    display_name: "Maria",
    must_change_password: true
  )
> Membership.create!(user:, site:, role: "admin")
> user.password
=> "…"   # share this over a secure channel
```

The user sees the forced-password-change screen on first sign-in and
picks a permanent password.

### Add an editor to an existing site

Same pattern as the first admin, but with `role: "editor"`.

### Reset a forgotten password

```
bin/rails console
> user = User.find_by!(email: "maria@example.com")
> user.update!(
    password: SecureRandom.urlsafe_base64(12),
    must_change_password: true
  )
> user.password
=> "…"   # share over a secure channel
```

### Rotate a site's deploy key

```
bin/rails cms:sites:rotate_deploy_key -- --slug=startupoulu
```

Generates a new keypair, prints the public half for GitHub, and
swaps `deploy_key_path` on the `Site` row only after the operator
confirms the new key is live on GitHub (task pauses for confirmation
at the TTY).
