#!/usr/bin/env bash
set -euo pipefail

COMPOSE=(docker compose -f docker-compose.yml -f docker-compose.test.yml)
BASE_URL="http://localhost:8080"
PASSED=0
FAILED=0

compose_up()   { "${COMPOSE[@]}" up -d; }
compose_down() { "${COMPOSE[@]}" down --remove-orphans > /dev/null 2>&1; }
compose_exec() { "${COMPOSE[@]}" exec "$@"; }

cleanup() {
    echo "Tearing down containers..."
    compose_down
}
trap cleanup EXIT

# Load site definitions
SITE_FILES=(sites/*/site.json)
if [ ${#SITE_FILES[@]} -eq 0 ]; then
    echo "FATAL: No site.json files found in sites/"
    exit 1
fi

echo "Starting containers..."
compose_up

echo "Validating Nginx configuration..."
if compose_exec nginx nginx -t 2>&1; then
    echo "PASS: Nginx configuration is valid"
    PASSED=$((PASSED + 1))
else
    echo "FAIL: Nginx configuration is invalid"
    FAILED=$((FAILED + 1))
fi

# Use the first site's path for readiness check
first_path=$(jq -r '.path' "${SITE_FILES[0]}")
echo "Waiting for Nginx to be ready..."
timeout=30
while ! curl -sf "$BASE_URL$first_path" > /dev/null 2>&1; do
    sleep 1
    timeout=$((timeout - 1))
    if [ "$timeout" -le 0 ]; then
        echo "FATAL: Nginx did not become ready within 30s"
        exit 1
    fi
done
echo "Nginx is ready."

run_test() {
    local name="$1"
    local url="$2"
    local expected="$3"
    local check_type="${4:-body}" # "body" or "status"

    if [ "$check_type" = "status" ]; then
        actual=$(curl -s -o /dev/null -w "%{http_code}" "$url")
        if [ "$actual" = "$expected" ]; then
            echo "PASS: $name"
            PASSED=$((PASSED + 1))
        else
            echo "FAIL: $name (expected status $expected, got $actual)"
            FAILED=$((FAILED + 1))
        fi
    else
        body=$(curl -sf "$url")
        if echo "$body" | grep -q "$expected"; then
            echo "PASS: $name"
            PASSED=$((PASSED + 1))
        else
            echo "FAIL: $name (expected body to contain '$expected')"
            FAILED=$((FAILED + 1))
        fi
    fi
}

echo ""
echo "Running tests..."

for site_file in "${SITE_FILES[@]}"; do
    name=$(jq -r '.name' "$site_file")
    path=$(jq -r '.path' "$site_file")
    expected_content=$(jq -r '.expected_content' "$site_file")
    enabled=$(jq -r 'if .enabled == false then "false" else "true" end' "$site_file")

    if [ "$enabled" = "true" ]; then
        run_test "$name returns 200" "$BASE_URL$path" "200" "status"
        run_test "$name serves correct content" "$BASE_URL$path" "$expected_content"
    else
        run_test "$name returns 404 (disabled)" "$BASE_URL$path" "404" "status"
    fi
done

run_test "Unknown route returns 404" "$BASE_URL/nonexistent" "404" "status"

echo ""
echo "Results: $PASSED passed, $FAILED failed"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
