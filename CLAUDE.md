# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run E2E tests (starts containers, runs tests, tears down automatically)
bash tests/e2e.sh

# Build nginx image only
docker compose build

# Start services manually (with test backends)
docker compose -f docker-compose.yml -f docker-compose.test.yml up -d

# Stop services
docker compose -f docker-compose.yml -f docker-compose.test.yml down --remove-orphans
```

## Architecture

Split-compose setup with a custom-built nginx reverse proxy image. `docker-compose.yml` defines the nginx proxy (built from `nginx/Dockerfile`); `docker-compose.test.yml` adds sample site backends for testing. Exposed on port 8080.

- **`nginx/Dockerfile`** — Builds from `nginx:alpine`, embeds `nginx.conf`, `sites-available/`, and `sites-enabled/` into the image
- **`docker-compose.yml`** — Production compose: builds and runs the nginx reverse proxy only
- **`docker-compose.test.yml`** — Test compose: adds site backend services plus `depends_on` to nginx. Merged with the main compose via `-f` flags.
- **`nginx/nginx.conf`** — Main nginx config with a single server block that includes location snippets from `sites-enabled/` and a catch-all 404
- **`nginx/sites-available/`** — Per-site location snippets (e.g. `site-a.conf` contains a `location /site-a/` with `proxy_pass`)
- **`nginx/sites-enabled/`** — Symlinks to configs in `sites-available/` that are active
- **`sites/`** — Static HTML content and `site.json` test definitions, each subdirectory is volume-mounted into its own `nginx:alpine` container by the test compose
- **`tests/e2e.sh`** — Bash E2E tests using `curl` and `jq`; discovers sites from `sites/*/site.json`, validates nginx config via `nginx -t`, tests HTTP status codes and content, and handles container lifecycle via `trap cleanup EXIT`

### Site JSON schema

Each site has a `site.json` with test metadata. Sites with `"enabled": false` are tested as negative cases (expect 404).

```json
{
  "name": "Site A",
  "path": "/site-a/",
  "expected_content": "Welcome to Site A",
  "enabled": true
}
```

The `enabled` field is optional and defaults to `true`.

### Adding a new site

1. Create `sites/site-x/index.html` and `sites/site-x/site.json`
2. Add `nginx/sites-available/site-x.conf` with a `location /site-x/` block
3. Symlink it: `ln -s ../sites-available/site-x.conf nginx/sites-enabled/site-x.conf`
4. Add a `site-x` service in `docker-compose.test.yml`
5. Add `site-x` to the `depends_on` list of the `nginx` service in `docker-compose.test.yml`
6. E2E tests pick up the new site automatically — no changes to `tests/e2e.sh` needed
