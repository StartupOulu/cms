# Deployment

Operational guide for installing and running the CMS in production.
Complements `AGENTS.md` (project map), `docs/architecture.md` (app
internals), and `docs/sites.md` (per-site operations).

Follows the approach described in Tuomas Jomppanen's
["Manually deploy Ruby on Rails 8 application to Linux server"](https://www.jomppanen.com/2024/11/20/manually-deploy-ruby-on-rails-8-application-to-linux-server.html).
No Docker, no Kamal, no containers. Just you and your Linux server.

## First-time setup checklist

### Once per server

- Ubuntu LTS (24.04 recommended) with a `deploy` user: SSH
  public-key auth and passwordless sudo (`NOPASSWD:ALL` in sudoers).
- At least 1 GB swap — Rails won't start reliably without it on a 1 GB
  RAM server. Add swap if `free` shows `Swap: 0`:
  ```bash
  sudo fallocate -l 1G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
  ```
- rbenv + Ruby (3.4+) + Bundler installed under the `deploy` user.
- System packages:
  ```bash
  sudo apt update
  sudo apt install -y curl git-core nginx sqlite3 libsqlite3-dev \
    build-essential libffi-dev libyaml-dev zlib1g-dev pkg-config \
    certbot python3-certbot-nginx
  ```
- UFW: allow 22/tcp, 80/tcp, 443/tcp.
- GitHub SSH host key trusted for the `deploy` user:
  ```bash
  ssh-keyscan github.com >> ~/.ssh/known_hosts
  ```
- DNS A-record for the CMS hostname → server IP.

### Once per CMS install

Create the persistent directory tree and set ownership:

```bash
sudo mkdir -p /var/www/apps/cms/{releases,logs,tmp/pids,tmp/sockets}
sudo mkdir -p /var/www/apps/cms/shared/{storage,repos,ssh}
sudo chown -R deploy:deploy /var/www/apps/cms
```

Copy `master.key` from local development to the server:

```bash
scp config/master.key deploy@yourserver:/var/www/apps/cms/shared/master.key
```

Configure Nginx (see section below), run Certbot, and create the
systemd service (see section below). Then run `bin/deplou` to
bootstrap the first release.

### Once per managed site

Create the site and admin user via Rails console (see Console recipes
below), then clone the website repo:

```bash
GIT_SSH_COMMAND="ssh -i /var/www/apps/cms/shared/ssh/<slug>/id_ed25519 -o StrictHostKeyChecking=no" \
  git clone <repo-url> /var/www/apps/cms/shared/repos/<slug>
```

The deploy key private file must have mode `600` — SSH refuses keys
with looser permissions:

```bash
chmod 600 /var/www/apps/cms/shared/ssh/<slug>/id_ed25519
```

The public half must be added to the website repo on GitHub under
**Settings → Deploy keys → Add deploy key** with **Allow write access**
ticked.

### Once per user

See Console recipes below.

## Server architecture

```
Firewall → Nginx (TLS + static assets) → Puma (Unix socket) → Rails app
                                                             → SQLite
```

Nginx handles HTTPS, serves `public/assets` directly, and proxies
everything else to Puma over a Unix socket. Let's Encrypt via Certbot
keeps TLS certificates current. Solid Queue runs inside Puma
(`SOLID_QUEUE_IN_PUMA=1`) — no separate process needed.

## Directory structure

```
/var/www/apps/cms/
├── current -> releases/<timestamp>   # symlink to latest deploy
├── logs/                             # Puma stdout/stderr logs
├── releases/                         # timestamped deploy directories
│   ├── 2026-05-13-19-56-49/
│   └── 2026-05-14-10-22-01/
├── shared/
│   ├── storage/                      # SQLite databases + Active Storage
│   ├── master.key                    # Rails credentials key
│   ├── repos/                        # per-site website-repo clones
│   │   └── <site-slug>/
│   └── ssh/                          # per-site SSH deploy keys
│       └── <site-slug>/
│           ├── id_ed25519            # must be chmod 600
│           └── id_ed25519.pub
└── tmp/
    ├── pids/
    └── sockets/                      # Puma socket file
```

- `shared/storage/` persists between deploys — symlinked into each release
- `shared/repos/<slug>/` holds each site's website-repo clone (publish + preview)
- `shared/ssh/<slug>/` holds each site's SSH deploy keypair; the `Site`
  record's `deploy_key_path` column stores the full path to the private key

## Puma configuration

See `config/puma.rb`. The production block binds to a Unix socket,
redirects logs, and runs Solid Queue in-process. Workers default to 1
(`WEB_CONCURRENCY`) — sufficient for a 1 GB server. Tune up once you
have headroom.

## Nginx virtual host

```nginx
# /etc/nginx/sites-available/cms
upstream rails_app {
  server unix:///var/www/apps/cms/tmp/sockets/puma.sock fail_timeout=0;
}

server {
  server_name cms.example.com;
  root /var/www/apps/cms/current/public;

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
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Host $http_host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_redirect off;

    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
  }
}
```

`X-Forwarded-Proto $scheme` is required — without it Rails sees
`request.base_url` as `http://` even over HTTPS, which causes CSRF
failures on every form submission (422 Unprocessable Content).

Symlink and reload:

```bash
sudo ln -s /etc/nginx/sites-available/cms /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d cms.example.com
```

## Systemd service

```ini
# /etc/systemd/system/cms.service
[Unit]
Description=StartupOulu CMS (Puma)
After=network.target

[Service]
Type=simple
User=deploy
WorkingDirectory=/var/www/apps/cms/current
Environment=RAILS_ENV=production
Environment=SOLID_QUEUE_IN_PUMA=1
ExecStart=/home/deploy/.rbenv/shims/bundle exec puma -C config/puma.rb
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl edit --force --full cms.service
sudo systemctl enable --now cms
```

## Deploy script (`bin/deplou`)

Run from local dev to deploy: `bin/deplou`

Steps performed:

1. `rsync` the app to a new timestamped release directory on the server
   (excluding `.git`, `storage/`, `shared/`, `tmp/`, credentials, sqlite files)
2. Copy `shared/master.key` into the release's `config/`
3. `bundle install`
4. `assets:precompile`
5. Update the `current` symlink to the new release
6. Symlink `shared/storage/` into `storage/`
7. Symlink `shared/repos/` and `shared/ssh/` into `shared/`
8. `db:prepare` (creates databases on first deploy; runs pending migrations on subsequent deploys)
9. `sudo systemctl restart cms`

Rollback: point `current` at the previous release directory and restart.

```bash
ln -nsf /var/www/apps/cms/releases/<previous-timestamp> /var/www/apps/cms/current
sudo systemctl restart cms
```

## Console recipes

### Create first site and admin user

```bash
RAILS_ENV=production bin/rails console
```

```ruby
site = Site.create!(
  name:                 "StartupOulu",
  slug:                 "startupoulu",
  repo_url:             "git@github.com:startupoulu/startupoulu.github.io.git",
  branch:               "main",
  site_url:             "https://startupoulu.com",
  clone_path:           "/var/www/apps/cms/shared/repos/startupoulu",
  deploy_key_path:      "/var/www/apps/cms/shared/ssh/startupoulu/id_ed25519",
  publish_author_name:  "StartupOulu CMS",
  publish_author_email: "cms@startupoulu.com"
)

user = User.create!(
  email_address:        "you@example.com",
  display_name:         "Your Name",
  password:             "change-this-on-first-login",
  must_change_password: true
)

site.memberships.create!(user: user, role: "admin")
```

`must_change_password: true` forces a password change on first sign-in.

### Add a subsequent user

Use the Users UI at `/users` (admin only) — no console needed.

### Update a site field

```ruby
Site.find_by(slug: "startupoulu").update!(deploy_key_path: "/var/www/apps/cms/shared/ssh/startupoulu/id_ed25519")
```

## Operational notes

- **Verify git integration:** visit `/admin/integrations` after setup —
  it runs live checks against the remote repo and flags any SSH or
  config problems.
- **Error log:** visit `/admin` to see application errors captured in
  the `error_logs` table.
- **Log rotation:** configure logrotate for Puma logs
  (`/var/www/apps/cms/logs/`) and Nginx logs, or the disk fills up.
- **Backups:** back up `shared/storage/` (SQLite DBs + uploads) and
  `shared/ssh/` (deploy keys) regularly. Follow the 3-2-1 rule.
  Consider Litestream for continuous SQLite replication to object storage.
- **The deploy script bypasses version control** — always commit and
  push before deploying. The script copies your local working tree,
  not a git ref.
