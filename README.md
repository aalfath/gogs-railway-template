[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/gogs-1?utm_medium=integration&utm_source=button&utm_campaign=gogs)

# Gogs on Railway

A one-click Railway template for [Gogs](https://gogs.io), the lightweight, self-hosted Git service: repositories, issues, pull requests, wikis, organisations and webhooks in one small Go binary.

## What it deploys

| Service | Source | Data |
|---|---|---|
| **Gogs** | this repo's `Dockerfile`: the official image `gogs/gogs:0.14.4`, pinned by digest | volume at `/data` (Git repositories, config, SSH host keys, avatars, attachments, LFS objects) |
| **Postgres** | Railway's PostgreSQL | volume at `/var/lib/postgresql/data` (users, issues, settings) |

Gogs gets a public `*.up.railway.app` domain on port 3000, a health check on `/healthcheck` (which also checks the database connection), and a Railway TCP proxy to port 22 for git over SSH.

## Variables

| Variable | Default | Notes |
|---|---|---|
| `GOGS_ADMIN_USERNAME` | `owner` | Admin account created on the first start. |
| `GOGS_ADMIN_PASSWORD` | `${{secret(24)}}` | Its password, generated per deploy. Read it in the service's **Variables** tab. |
| `GOGS_ADMIN_EMAIL` | empty (optional) | The admin's email. Defaults to `owner@<your Railway domain>`; you can change it later in Gogs. |
| `GOGS_SECRET_KEY` | `${{secret(32)}}` | Signs cookies and encrypts 2FA secrets. Generated per deploy; don't change it later. |
| `GOGS_DB_HOST`, `GOGS_DB_NAME`, `GOGS_DB_USER`, `GOGS_DB_PASSWORD` | references to `Postgres` | Private-network connection to the bundled database. |
| `PORT` | `3000` | Port the web UI listens on; the public domain targets it. |

Nothing to fill in at deploy time.

The start script (`railway-start.sh`) writes `/data/gogs/conf/app.ini` from these variables on every start, so the web install wizard never opens and nobody can claim a fresh instance before you. It sets the public URL from the Railway domain, keeps every data path on the volume, and turns self-registration **off** (the admin adds users under **Admin Panel → Users**).

Optional settings:

- `GOGS_EXTERNAL_URL`: your custom domain, e.g. `https://git.YOUR-DOMAIN`. Set it when you add one, so clone URLs and links use it.
- `GOGS_DISABLE_REGISTRATION=false`: let anyone sign up. `GOGS_REQUIRE_SIGNIN_VIEW=true`: hide everything from visitors who aren't signed in.
- Any other `app.ini` setting as `GOGS__<section>__<KEY>`, for example `GOGS__email__ENABLED=true`, `GOGS__email__HOST=smtp.YOUR-DOMAIN:587`. A dot in a section name is written `_0X2E_` (`GOGS__repository_0X2E_upload__FILE_MAX_SIZE=50`). See the [`app.ini` reference](https://github.com/gogs/gogs/blob/v0.14.4/conf/app.ini).

## Git over SSH

HTTPS clone and push work out of the box, and so does SSH: the template adds a Railway **TCP proxy** to the container's OpenSSH on port 22. The start script reads the proxy's host and port (`RAILWAY_TCP_PROXY_DOMAIN`, `RAILWAY_TCP_PROXY_PORT`) and shows clone URLs like `ssh://git@<host>.proxy.rlwy.net:<port>/owner/repo.git`. Add your public key under **Your Settings → SSH Keys**. OpenSSH accepts keys only (no passwords) and only for the `git` user. If you remove the TCP proxy, SSH is switched off in Gogs on the next deploy. To show a different SSH host or port, set `GOGS_SSH_DOMAIN` and `GOGS_SSH_PORT`.

## After deploy

Open the public URL and sign in as `owner` with the `GOGS_ADMIN_PASSWORD` from the Variables tab. The admin is created about 10 seconds after the first start. Changing `GOGS_ADMIN_PASSWORD` later doesn't change the password: use **Your Settings → Password** in Gogs.

## Updates

Each Gogs release is a new commit to `main` here that bumps the pinned tag and digest, with a [`CHANGELOG.md`](CHANGELOG.md) entry (breaking changes first). Railway then shows an "update available" notice in projects deployed from this template, and you choose when to apply it. Gogs migrates its database on start and migrations only run forward, so back up the Postgres database and the `/data` volume first.

## Licence

Gogs is MIT-licensed, by the Gogs authors. This wrapper only adds a start script.
