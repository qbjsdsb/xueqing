#!/usr/bin/env bash
set -euo pipefail

# Phase 0B.0-A remote security spike.
#
# This script is deliberately separate from the local Supabase test. It may
# run only against a disposable, fictional-data development project. It uses
# the public publishable key and keeps access tokens in memory only.

: "${XUEQING_SPIKE_CONFIRM_DEV_ONLY:?Set XUEQING_SPIKE_CONFIRM_DEV_ONLY=YES for a fictional-data development project}"
if [ "$XUEQING_SPIKE_CONFIRM_DEV_ONLY" != "YES" ]; then
  echo "Refusing to run: XUEQING_SPIKE_CONFIRM_DEV_ONLY must be YES." >&2
  exit 1
fi

: "${XUEQING_SPIKE_PROJECT_REF:?Set the expected Supabase project ref; this is a safety check}"
: "${XUEQING_SUPABASE_URL:?Set the Supabase project URL}"
: "${XUEQING_SUPABASE_PUBLISHABLE_KEY:?Set the Supabase publishable/anon key}"
: "${XUEQING_SPIKE_TEACHER_A_EMAIL:?Set the fictional Teacher A email}"
: "${XUEQING_SPIKE_TEACHER_A_PASSWORD:?Set the fictional Teacher A password}"
: "${XUEQING_SPIKE_TEACHER_B_EMAIL:?Set the fictional Teacher B email}"
: "${XUEQING_SPIKE_TEACHER_B_PASSWORD:?Set the fictional Teacher B password}"
: "${XUEQING_SPIKE_NO_MEMBERSHIP_EMAIL:?Set the fictional no-membership email}"
: "${XUEQING_SPIKE_NO_MEMBERSHIP_PASSWORD:?Set the fictional no-membership password}"

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required." >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required." >&2
  exit 1
fi

base_url="$(printf '%s' "$XUEQING_SUPABASE_URL" | sed 's:/*$::')"
case "$base_url" in
  https://*.supabase.co) ;;
  *)
    echo "Refusing to run: XUEQING_SUPABASE_URL must be an https://<project-ref>.supabase.co URL." >&2
    exit 1
    ;;
esac

actual_host="${base_url#https://}"
if [ "$actual_host" != "$XUEQING_SPIKE_PROJECT_REF.supabase.co" ]; then
  echo "Refusing to run: URL host does not match XUEQING_SPIKE_PROJECT_REF." >&2
  exit 1
fi

temp_dir="$(mktemp -d)"
cleanup() {
  rm -f "$temp_dir"/*
  rmdir "$temp_dir"
}
trap cleanup EXIT

request() {
  local method="$1"
  local url="$2"
  local body_file="$3"
  local access_token="${4:-}"

  if [ -n "$access_token" ]; then
    curl --silent --show-error \
      --output "$body_file" \
      --write-out '%{http_code}' \
      --request "$method" \
      --url "$url" \
      --header "apikey: $XUEQING_SUPABASE_PUBLISHABLE_KEY" \
      --header "Authorization: Bearer $access_token"
  else
    curl --silent --show-error \
      --output "$body_file" \
      --write-out '%{http_code}' \
      --request "$method" \
      --url "$url" \
      --header "apikey: $XUEQING_SUPABASE_PUBLISHABLE_KEY"
  fi
}

login() {
  local email="$1"
  local password="$2"
  local payload
  payload="$(jq -n --arg email "$email" --arg password "$password" \
    '{email: $email, password: $password}')"

  local response
  local status
  response="$(printf '%s' "$payload" | curl --silent --show-error \
    --write-out '\n%{http_code}' \
    --request POST \
    --url "$base_url/auth/v1/token?grant_type=password" \
    --header "apikey: $XUEQING_SUPABASE_PUBLISHABLE_KEY" \
    --header 'Content-Type: application/json' \
    --data-binary @-)"
  status="${response##*$'\n'}"

  if [ "$status" != "200" ]; then
    echo "Password login failed (HTTP $status)." >&2
    exit 1
  fi

  response="${response%$'\n'*}"
  printf '%s' "$response" | jq --exit-status --raw-output \
    '.access_token | strings | select(length > 0)'
}

assert_json() {
  local body_file="$1"
  local filter="$2"
  local label="$3"
  if ! jq --exit-status "$filter" "$body_file" >/dev/null; then
    echo "FAIL: $label" >&2
    exit 1
  fi
  echo "PASS: $label"
}

assert_status_and_json() {
  local status="$1"
  local expected_status="$2"
  local body_file="$3"
  local filter="$4"
  local label="$5"
  if [ "$status" != "$expected_status" ]; then
    echo "FAIL: $label (HTTP $status)" >&2
    exit 1
  fi
  assert_json "$body_file" "$filter" "$label"
}

assert_denied_rows() {
  local status="$1"
  local body_file="$2"
  local label="$3"
  case "$status" in
    200)
      assert_json "$body_file" 'type == "array" and length == 0' "$label"
      ;;
    401|403)
      echo "PASS: $label (HTTP $status)"
      ;;
    *)
      echo "FAIL: $label (unexpected HTTP $status)" >&2
      exit 1
      ;;
  esac
}

student_a_id="30000000-0000-0000-0000-000000000001"
student_b_id="30000000-0000-0000-0000-000000000002"
organization_a_id="00000000-0000-0000-0000-000000000001"
organization_b_id="00000000-0000-0000-0000-000000000002"

teacher_a_students="$temp_dir/teacher-a-students.json"
teacher_a_cross_student="$temp_dir/teacher-a-cross-student.json"
teacher_a_cross_org="$temp_dir/teacher-a-cross-org.json"
teacher_a_memberships="$temp_dir/teacher-a-memberships.json"
teacher_a_assignments="$temp_dir/teacher-a-assignments.json"
teacher_a_app_user="$temp_dir/teacher-a-app-user.json"
teacher_b_students="$temp_dir/teacher-b-students.json"
teacher_b_cross_student="$temp_dir/teacher-b-cross-student.json"
teacher_b_cross_org="$temp_dir/teacher-b-cross-org.json"
teacher_b_memberships="$temp_dir/teacher-b-memberships.json"
teacher_b_assignments="$temp_dir/teacher-b-assignments.json"
no_membership_students="$temp_dir/no-membership-students.json"
no_membership_orgs="$temp_dir/no-membership-orgs.json"
no_membership_memberships="$temp_dir/no-membership-memberships.json"
after_logout_students="$temp_dir/after-logout-students.json"
after_logout_app_user="$temp_dir/after-logout-app-user.json"

teacher_a_token="$(login "$XUEQING_SPIKE_TEACHER_A_EMAIL" \
  "$XUEQING_SPIKE_TEACHER_A_PASSWORD")"
teacher_b_token="$(login "$XUEQING_SPIKE_TEACHER_B_EMAIL" \
  "$XUEQING_SPIKE_TEACHER_B_PASSWORD")"
no_membership_token="$(login "$XUEQING_SPIKE_NO_MEMBERSHIP_EMAIL" \
  "$XUEQING_SPIKE_NO_MEMBERSHIP_PASSWORD")"

teacher_a_status="$(request GET \
  "$base_url/rest/v1/app_users?select=display_name,auth_provider" \
  "$teacher_a_app_user" "$teacher_a_token")"
assert_status_and_json "$teacher_a_status" 200 "$teacher_a_app_user" \
  'type == "array" and length == 1 and .[0].display_name == "王老师" and .[0].auth_provider == "supabase"' \
  "Teacher A resolves to the provider-neutral application identity"

teacher_a_status="$(request GET \
  "$base_url/rest/v1/memberships?select=organization_id,role,status&status=eq.active" \
  "$teacher_a_memberships" "$teacher_a_token")"
assert_status_and_json "$teacher_a_status" 200 "$teacher_a_memberships" \
  "type == \"array\" and length == 1 and .[0].organization_id == \"$organization_a_id\" and .[0].role == \"teacher\"" \
  "Teacher A has one active membership in Organization A"

teacher_a_status="$(request GET \
  "$base_url/rest/v1/teacher_assignments?select=student_id,subject,status&status=eq.active" \
  "$teacher_a_assignments" "$teacher_a_token")"
assert_status_and_json "$teacher_a_status" 200 "$teacher_a_assignments" \
  "type == \"array\" and length == 1 and .[0].student_id == \"$student_a_id\"" \
  "Teacher A has one active assignment"

teacher_a_status="$(request GET \
  "$base_url/rest/v1/students?select=id,name,organization_id&order=id" \
  "$teacher_a_students" "$teacher_a_token")"
assert_status_and_json "$teacher_a_status" 200 "$teacher_a_students" \
  "type == \"array\" and length == 1 and .[0].id == \"$student_a_id\" and .[0].name == \"林雨桐\"" \
  "Teacher A can read Student A"

teacher_a_status="$(request GET \
  "$base_url/rest/v1/students?id=eq.$student_b_id&select=id" \
  "$teacher_a_cross_student" "$teacher_a_token")"
assert_denied_rows "$teacher_a_status" "$teacher_a_cross_student" \
  "Teacher A cannot read Student B"

teacher_a_status="$(request GET \
  "$base_url/rest/v1/organizations?id=eq.$organization_b_id&select=id" \
  "$teacher_a_cross_org" "$teacher_a_token")"
assert_denied_rows "$teacher_a_status" "$teacher_a_cross_org" \
  "Teacher A cannot read Organization B"

teacher_b_status="$(request GET \
  "$base_url/rest/v1/memberships?select=organization_id,role,status&status=eq.active" \
  "$teacher_b_memberships" "$teacher_b_token")"
assert_status_and_json "$teacher_b_status" 200 "$teacher_b_memberships" \
  "type == \"array\" and length == 1 and .[0].organization_id == \"$organization_b_id\" and .[0].role == \"teacher\"" \
  "Teacher B has one active membership in Organization B"

teacher_b_status="$(request GET \
  "$base_url/rest/v1/teacher_assignments?select=student_id,subject,status&status=eq.active" \
  "$teacher_b_assignments" "$teacher_b_token")"
assert_status_and_json "$teacher_b_status" 200 "$teacher_b_assignments" \
  "type == \"array\" and length == 1 and .[0].student_id == \"$student_b_id\"" \
  "Teacher B has one active assignment"

teacher_b_status="$(request GET \
  "$base_url/rest/v1/students?select=id,name,organization_id&order=id" \
  "$teacher_b_students" "$teacher_b_token")"
assert_status_and_json "$teacher_b_status" 200 "$teacher_b_students" \
  "type == \"array\" and length == 1 and .[0].id == \"$student_b_id\" and .[0].name == \"陈宇航\"" \
  "Teacher B can read Student B"

teacher_b_status="$(request GET \
  "$base_url/rest/v1/students?id=eq.$student_a_id&select=id" \
  "$teacher_b_cross_student" "$teacher_b_token")"
assert_denied_rows "$teacher_b_status" "$teacher_b_cross_student" \
  "Teacher B cannot read Student A"

teacher_b_status="$(request GET \
  "$base_url/rest/v1/organizations?id=eq.$organization_a_id&select=id" \
  "$teacher_b_cross_org" "$teacher_b_token")"
assert_denied_rows "$teacher_b_status" "$teacher_b_cross_org" \
  "Teacher B cannot read Organization A"

no_membership_status="$(request GET \
  "$base_url/rest/v1/memberships?select=id&status=eq.active" \
  "$no_membership_memberships" "$no_membership_token")"
assert_status_and_json "$no_membership_status" 200 "$no_membership_memberships" \
  'type == "array" and length == 0' \
  "A user without membership has no active membership"

no_membership_status="$(request GET \
  "$base_url/rest/v1/organizations?select=id" \
  "$no_membership_orgs" "$no_membership_token")"
assert_status_and_json "$no_membership_status" 200 "$no_membership_orgs" \
  'type == "array" and length == 0' \
  "A user without membership cannot read organizations"

no_membership_status="$(request GET \
  "$base_url/rest/v1/students?select=id" \
  "$no_membership_students" "$no_membership_token")"
assert_status_and_json "$no_membership_status" 200 "$no_membership_students" \
  'type == "array" and length == 0' \
  "A user without membership cannot read students"

# Keep the pre-logout token in memory and test the protected API after the
# current session is revoked. A 200 with zero rows is an intentional pass:
# the API may accept the JWT transport-wise while the live-session RLS helper
# denies every business row. A 401/403 is also a pass.
logout_status="$(request POST "$base_url/auth/v1/logout" "$temp_dir/logout.json" "$teacher_a_token")"
case "$logout_status" in
  200|204) ;;
  *)
    echo "FAIL: logout returned HTTP $logout_status" >&2
    exit 1
    ;;
esac
echo "PASS: Teacher A logout revoked the current session (HTTP $logout_status)"

after_logout_status="$(request GET \
  "$base_url/rest/v1/students?select=id" \
  "$after_logout_students" "$teacher_a_token")"
assert_denied_rows "$after_logout_status" "$after_logout_students" \
  "The old Teacher A token cannot read students after logout"

after_logout_status="$(request GET \
  "$base_url/rest/v1/app_users?select=id" \
  "$after_logout_app_user" "$teacher_a_token")"
assert_denied_rows "$after_logout_status" "$after_logout_app_user" \
  "The old Teacher A token cannot resolve an application identity after logout"

echo "REMOTE_SPIKE_RESULT=PASS"
echo "REMOTE_SPIKE_SCOPE=fictional-development-data-only"
