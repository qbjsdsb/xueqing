#!/usr/bin/env bash
set -euo pipefail

# This test runs only against the local Supabase development stack.
# It uses fictional seed credentials and never writes an access token to disk.

status_env="$(supabase status -o env)"
eval "$status_env"

: "${API_URL:?supabase status did not return API_URL}"
: "${ANON_KEY:?supabase status did not return ANON_KEY}"

login_response="$(
  curl --fail-with-body --silent --show-error \
    --request POST \
    --url "${API_URL}/auth/v1/token?grant_type=password" \
    --header "apikey: ${ANON_KEY}" \
    --header "Content-Type: application/json" \
    --data '{"email":"teacher.a@xueqing.test","password":"XueqingDev-Only-123!"}'
)"

access_token="$(printf '%s' "${login_response}" | jq --exit-status --raw-output '.access_token')"
test -n "${access_token}"

# Keep the pre-revocation token in memory as the old-token fixture.
old_access_token="${access_token}"

before_body="$(mktemp)"
trap 'rm -f "${before_body}" "${after_body:-}"' EXIT

before_status="$(
  curl --silent --show-error \
    --output "${before_body}" \
    --write-out '%{http_code}' \
    --url "${API_URL}/rest/v1/students?select=id,name" \
    --header "apikey: ${ANON_KEY}" \
    --header "Authorization: Bearer ${old_access_token}"
)"

test "${before_status}" = "200"
jq --exit-status 'length == 1 and .[0].name == "林雨桐"' "${before_body}" >/dev/null

logout_status="$(
  curl --silent --show-error \
    --output /dev/null \
    --write-out '%{http_code}' \
    --request POST \
    --url "${API_URL}/auth/v1/logout" \
    --header "apikey: ${ANON_KEY}" \
    --header "Authorization: Bearer ${access_token}"
)"

case "${logout_status}" in
  200|204) ;;
  *)
    echo "logout returned unexpected HTTP status: ${logout_status}" >&2
    exit 1
    ;;
esac

after_body="$(mktemp)"
after_status="$(
  curl --silent --show-error \
    --output "${after_body}" \
    --write-out '%{http_code}' \
    --url "${API_URL}/rest/v1/students?select=id,name" \
    --header "apikey: ${ANON_KEY}" \
    --header "Authorization: Bearer ${old_access_token}"
)"

if [ "${after_status}" = "200" ]; then
  jq --exit-status 'type == "array" and length == 0' "${after_body}" >/dev/null
elif [ "${after_status}" = "401" ] || [ "${after_status}" = "403" ]; then
  :
else
  echo "old token returned unexpected HTTP status: ${after_status}" >&2
  cat "${after_body}" >&2
  exit 1
fi

echo "old-token request was denied after logout (HTTP ${after_status})"
