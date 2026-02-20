# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run E2E tests (starts containers, runs tests, tears down automatically)
bash tests/e2e.sh

# Start services manually
docker compose up -d

# Stop services
docker compose down --remove-orphans
```

## Architecture

Split-compose setup: `docker-compose.yml` defines the nginx reverse proxy only; `docker-compose.test.yml` adds sample site backends for testing. Exposed on port 8080.

- **`docker-compose.yml`** — Production compose: nginx reverse proxy only
- **`docker-compose.test.yml`** — Test compose: adds `site-a` and `site-b` backend services plus `depends_on` to nginx. Merged with the main compose via `-f` flags.
- **`nginx/default.conf`** — Reverse proxy config using `proxy_pass` to route each path to its backend container by Docker Compose service name, with a catch-all 404
- **`sites/`** — Static HTML content for test sites, each subdirectory is volume-mounted into its own `nginx:alpine` container
- **`tests/e2e.sh`** — Bash E2E tests using `curl`; merges both compose files and handles container lifecycle via `trap cleanup EXIT`

### Adding a new test site

1. Create `sites/site-c/index.html`
2. Add a `site-c` service in `docker-compose.test.yml`
3. Add `site-c` to the `depends_on` list of the `nginx` service in `docker-compose.test.yml`
4. Add a `location /site-c/` block with `proxy_pass http://site-c/;` in `nginx/default.conf`
5. Add test cases in `tests/e2e.sh`
