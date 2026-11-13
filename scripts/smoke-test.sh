#!/usr/bin/env bash
#
# Smoke test for a running todo-app instance.
#
# Sends real HTTP requests to the packaged application and checks the
# status code of each. The unit and slice tests run against H2 with
# mocked services; this exercises the assembled jar, its security
# filter chains and a real PostgreSQL.
#
# Usage:
#   scripts/smoke-test.sh [BASE_URL]
#
# BASE_URL defaults to http://localhost:8081. Start the application
# first, for example:
#   java -jar target/todo-app-1.0.0-SNAPSHOT.jar
#
# Each run registers one user named smoke_<epoch-seconds>; the row is
# left in the database.
#
# Exit status: 0 when every check passes, 1 otherwise.

set -u

BASE_URL="${1:-http://localhost:8081}"
RUN_ID="$(date +%s)"
USERNAME="smoke_${RUN_ID}"
PASSWORD="smoke-pass-${RUN_ID}"
LONG_PASSWORD="$(printf 'a%.0s' $(seq 1 100))"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

failures=0

# status METHOD PATH [JSON_BODY | @FILE] -> prints the HTTP status code
status() {
    local method="$1" path="$2" body="${3:-}"
    if [ -n "${body}" ]; then
        curl -s -o /dev/null -w '%{http_code}' -X "${method}" \
            -H 'Content-Type: application/json' \
            --data-binary "${body}" "${BASE_URL}${path}"
    else
        curl -s -o /dev/null -w '%{http_code}' -X "${method}" "${BASE_URL}${path}"
    fi
}

# check NAME EXPECTED ACTUAL
check() {
    local name="$1" expected="$2" actual="$3"
    if [ "${actual}" = "${expected}" ]; then
        printf 'PASS  %-46s %s\n' "${name}" "${actual}"
    else
        printf 'FAIL  %-46s %s (expected %s)\n' "${name}" "${actual}" "${expected}"
        failures=$((failures + 1))
    fi
}

printf 'Smoke test against %s (user %s)\n\n' "${BASE_URL}" "${USERNAME}"

if ! curl -s -o /dev/null --retry 15 --retry-connrefused --retry-delay 2 "${BASE_URL}/"; then
    printf 'FAIL  no application answering at %s\n' "${BASE_URL}"
    exit 1
fi

# --- Static frontend, served by the web filter chain -------------------
check 'GET / (index)' 200 "$(status GET /)"

main_js="$(curl -s "${BASE_URL}/index.html" | grep -o 'main\.[A-Za-z0-9]*\.js' | head -n 1)"
if [ -n "${main_js}" ]; then
    check "GET /${main_js} (static, /*.js)" 200 "$(status GET "/${main_js}")"
else
    printf 'FAIL  %-46s %s\n' 'index.html names a main.*.js bundle' 'not found'
    failures=$((failures + 1))
fi

# --- Auth endpoints: public, validated ---------------------------------
check 'POST /api/v1/auth/register' 200 "$(status POST /api/v1/auth/register \
    "{\"username\":\"${USERNAME}\",\"email\":\"${USERNAME}@example.com\",\"password\":\"${PASSWORD}\"}")"

check 'POST /api/v1/auth/login' 200 "$(status POST /api/v1/auth/login \
    "{\"username\":\"${USERNAME}\",\"password\":\"${PASSWORD}\"}")"

check 'POST /api/v1/auth/login, wrong password' 401 "$(status POST /api/v1/auth/login \
    "{\"username\":\"${USERNAME}\",\"password\":\"not-the-password\"}")"

# Input validation (formerly the compensating control for
# CVE-2025-22228): passwords over 72 characters are rejected by Bean
# Validation before they reach BCrypt.
check 'POST /api/v1/auth/login, 100-char password' 400 "$(status POST /api/v1/auth/login \
    "{\"username\":\"${USERNAME}\",\"password\":\"${LONG_PASSWORD}\"}")"

check 'POST /api/v1/auth/register, 100-char password' 400 "$(status POST /api/v1/auth/register \
    "{\"username\":\"${USERNAME}x\",\"email\":\"${USERNAME}x@example.com\",\"password\":\"${LONG_PASSWORD}\"}")"

# --- API filter chain: public and protected paths ----------------------
check 'GET /api/v1/todos (public)' 200 "$(status GET /api/v1/todos)"
check "GET /api/v1/users/username/${USERNAME} (public)" 200 \
    "$(status GET "/api/v1/users/username/${USERNAME}")"
check 'GET /api/v1/users (protected, no credentials)' 403 "$(status GET /api/v1/users)"

# --- Observation, not a pass/fail check --------------------------------
# application.properties sets a 2 MB form-post limit
# (server.tomcat.max-http-post-size and max-http-form-post-size). That
# limit does not apply to JSON bodies. This posts a 3 MB JSON body and
# reports what the application answers: 400 means the body was read
# and rejected by Bean Validation, not refused by the container.
big_body="${WORK_DIR}/big.json"
{
    printf '{"username":"%s","password":"' "${USERNAME}"
    head -c 3000000 /dev/zero | tr '\0' 'a'
    printf '"}'
} > "${big_body}"
printf 'INFO  %-46s %s\n' 'POST /api/v1/auth/login, 3 MB JSON body' \
    "$(status POST /api/v1/auth/login "@${big_body}")"

printf '\n'
if [ "${failures}" -eq 0 ]; then
    printf 'All checks passed.\n'
    exit 0
fi
printf '%s check(s) failed.\n' "${failures}"
exit 1
