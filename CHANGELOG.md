# Changelog

Breaking changes are listed first in each entry. Read the entry before you apply an update in Railway, and back up the Postgres database and the `/data` volume first: Gogs migrations only run forward.

## 0.14.4 (2026-11-18)

- First release of this template: Gogs [v0.14.4](https://github.com/gogs/gogs/releases/tag/v0.14.4), image `gogs/gogs:0.14.4@sha256:ad893b78298754fe83010b3fa3cfe6b3f6cf42dfb8944fdb42c9a75e7420056b`.
- Bundled Railway Postgres, all Gogs data on a `/data` volume, health check on `/healthcheck`, config written from variables (no install wizard), admin account with a generated password, self-registration off, git over SSH through a Railway TCP proxy to port 22.
- README: Deploy on Railway button for the published template `gogs-1`.
