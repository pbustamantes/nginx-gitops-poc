#!/usr/bin/env bash
set -euo pipefail

COMPOSE="docker compose -f docker-compose.yml -f docker-compose.test.yml"
BASE_URL="http://localhost:8080"
PASSED=0
FAILED=0

cleanup() {
    echo "Tearing down containers..."
    $COMPOSE down --remove-orphans > /dev/null 2>&1
}
trap cleanup EXIT

echo "Starting containers..."
$COMPOSE up -d

echo "Waiting for Nginx to be ready..."
timeout=30
while ! curl -sf "$BASE_URL/site-a/" > /dev/null 2>&1; do
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
run_test "Site A serves correct content" "$BASE_URL/site-a/" "Welcome to Site A"
run_test "Site B serves correct content" "$BASE_URL/site-b/" "Welcome to Site B"
run_test "Unknown route returns 404"     "$BASE_URL/nonexistent" "404" "status"

echo ""
echo "Results: $PASSED passed, $FAILED failed"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
