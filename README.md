# nginx-gitops-poc

A Docker-based Nginx reverse proxy with path-based routing to independent site containers, managed via a GitOps-friendly `sites-available`/`sites-enabled` pattern.

## Prerequisites

- Docker and Docker Compose
- `jq` (used by the E2E test script)

## Quick Start

```bash
# Run the full E2E test suite
bash tests/e2e.sh
```

This starts all containers, runs the tests, and tears everything down automatically.

## How It Works

An Nginx reverse proxy listens on port **8080** and routes requests by path (`/site-a/`, `/site-b/`, etc.) to dedicated backend containers. Each backend is its own `nginx:alpine` instance serving static HTML.

```
Client → :8080/site-a/ → [nginx proxy] → [site-a container]
              /site-b/                  → [site-b container]
              /site-c/                  → [site-c container]
              /*                        → 404
```

### Nginx Configuration

Follows the `sites-available`/`sites-enabled` convention:

- **`nginx/sites-available/`** — One file per site containing a `location` block
- **`nginx/sites-enabled/`** — Symlinks to active configs
- **`nginx/nginx.conf`** — Includes all enabled sites into a single server block

Disable a site by removing its symlink from `sites-enabled/`.

### Docker Compose

Split into two files:

- **`docker-compose.yml`** — The Nginx reverse proxy (production-like)
- **`docker-compose.test.yml`** — Sample site backends for testing, merged via `-f` flags

### E2E Tests

The test script (`tests/e2e.sh`) discovers sites dynamically by reading `sites/*/site.json` files. Each `site.json` defines:

```json
{
  "name": "Site A",
  "path": "/site-a/",
  "expected_content": "Welcome to Site A"
}
```

No test code changes are needed when adding a new site.

## Adding a New Site

1. Create the site content and test definition:
   ```
   sites/site-x/index.html
   sites/site-x/site.json
   ```

2. Add the Nginx location config and enable it:
   ```bash
   # Create nginx/sites-available/site-x.conf with a location block
   ln -s ../sites-available/site-x.conf nginx/sites-enabled/site-x.conf
   ```

3. Add the backend service in `docker-compose.test.yml` and include it in nginx's `depends_on`

4. Run `bash tests/e2e.sh` — the new site is picked up automatically
