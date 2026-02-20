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

This builds the nginx image, starts all containers, runs the tests, and tears everything down automatically.

## How It Works

A custom nginx Docker image (built from `nginx/Dockerfile`) acts as a reverse proxy on port **8080**, routing requests by path to dedicated backend containers. Each backend is its own `nginx:alpine` instance serving static HTML.

```
Client → :8080/site-a/ → [nginx proxy] → [site-a container]
              /site-b/                  → [site-b container]
              /site-c/                  → [site-c container]
              /*                        → 404
```

### Nginx Image

The proxy is built from `nginx/Dockerfile`, which embeds all configuration into the image:

- **`nginx/nginx.conf`** — Includes all enabled sites into a single server block
- **`nginx/sites-available/`** — One file per site containing a `location` block
- **`nginx/sites-enabled/`** — Symlinks to active configs

Disable a site by removing its symlink from `sites-enabled/` and rebuilding the image.

### Docker Compose

Split into two files:

- **`docker-compose.yml`** — Builds and runs the nginx reverse proxy
- **`docker-compose.test.yml`** — Adds sample site backends for testing, merged via `-f` flags

### E2E Tests

The test script (`tests/e2e.sh`) discovers sites dynamically by reading `sites/*/site.json` files. Each `site.json` defines:

```json
{
  "name": "Site A",
  "path": "/site-a/",
  "expected_content": "Welcome to Site A"
}
```

Tests include:
- **Config validation** — `nginx -t` inside the container
- **Status checks** — enabled sites return HTTP 200
- **Content checks** — response body contains expected content
- **Negative tests** — disabled sites (with `"enabled": false`) return HTTP 404

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

## CI

GitHub Actions runs the E2E test suite on every push and pull request to `main`. The workflow builds the nginx image first, then executes the tests.
