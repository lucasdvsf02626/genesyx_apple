#!/bin/zsh

set -euo pipefail

readonly SUPABASE_URL="https://epltxklawpcxxbaleswg.supabase.co"
readonly SUPABASE_ANON_KEY="sb_publishable_eR7nEFBHD_4ATbjEeRbicA_Z3Qj_Elb"

for command_name in curl jq; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    print -u2 "Missing required command: $command_name"
    exit 1
  fi
done

review_email="${GENESYX_REVIEW_EMAIL:-}"
review_password="${GENESYX_REVIEW_PASSWORD:-}"

if [[ -z "$review_email" ]]; then
  read "review_email?App Review email: "
fi

if [[ -z "$review_password" ]]; then
  read -s "review_password?App Review password: "
  print
fi

if [[ -z "$review_email" || -z "$review_password" ]]; then
  print -u2 "Email and password are required."
  exit 1
fi

auth_response="$(mktemp -t genesyx-review-auth.XXXXXX)"
profile_response="$(mktemp -t genesyx-review-profile.XXXXXX)"
cycle_response="$(mktemp -t genesyx-review-cycle.XXXXXX)"
logs_response="$(mktemp -t genesyx-review-logs.XXXXXX)"
ph_response="$(mktemp -t genesyx-review-ph.XXXXXX)"

cleanup() {
  rm -f "$auth_response" "$profile_response" "$cycle_response" "$logs_response" "$ph_response"
}
trap cleanup EXIT INT TERM

auth_status="$({
  jq -nc --arg email "$review_email" --arg password "$review_password" \
    '{email:$email,password:$password}' |
    curl --silent --show-error \
      --output "$auth_response" \
      --write-out '%{http_code}' \
      --request POST "$SUPABASE_URL/auth/v1/token?grant_type=password" \
      --header "apikey: $SUPABASE_ANON_KEY" \
      --header 'Content-Type: application/json' \
      --data-binary @-
})"

unset review_password
unset GENESYX_REVIEW_PASSWORD 2>/dev/null || true

if [[ "$auth_status" != "200" ]]; then
  error_message="$(jq -r '.msg // .error_description // .message // "Unknown authentication error"' "$auth_response")"
  print -u2 "Review account check FAILED (HTTP $auth_status): $error_message"
  exit 1
fi

access_token="$(jq -r '.access_token // empty' "$auth_response")"
user_id="$(jq -r '.user.id // empty' "$auth_response")"
authenticated_email="$(jq -r '.user.email // empty' "$auth_response")"

if [[ -z "$access_token" || -z "$user_id" || "$authenticated_email" != "$review_email" ]]; then
  print -u2 "Review account check FAILED: the backend did not return the expected authenticated user."
  exit 1
fi

readonly auth_header="Authorization: Bearer $access_token"
readonly api_header="apikey: $SUPABASE_ANON_KEY"

curl --silent --show-error \
  "$SUPABASE_URL/rest/v1/profiles?select=id&id=eq.$user_id" \
  --header "$api_header" --header "$auth_header" > "$profile_response"
curl --silent --show-error \
  "$SUPABASE_URL/rest/v1/cycle_settings?select=user_id&user_id=eq.$user_id" \
  --header "$api_header" --header "$auth_header" > "$cycle_response"
curl --silent --show-error \
  "$SUPABASE_URL/rest/v1/daily_logs?select=date&user_id=eq.$user_id" \
  --header "$api_header" --header "$auth_header" > "$logs_response"
curl --silent --show-error \
  "$SUPABASE_URL/rest/v1/ph_readings?select=id&user_id=eq.$user_id&deleted_at=is.null" \
  --header "$api_header" --header "$auth_header" > "$ph_response"

profile_count="$(jq 'length' "$profile_response")"
cycle_count="$(jq 'length' "$cycle_response")"
log_count="$(jq 'length' "$logs_response")"
ph_count="$(jq 'length' "$ph_response")"

if (( profile_count < 1 || cycle_count < 1 || log_count < 1 || ph_count < 1 )); then
  print -u2 "Review account login works, but sample data is incomplete."
  print -u2 "profile=$profile_count cycle=$cycle_count daily_logs=$log_count ph_readings=$ph_count"
  exit 1
fi

print "Review account check PASSED."
print "Authentication: password login succeeded"
print "Review data: profile=$profile_count cycle=$cycle_count daily_logs=$log_count ph_readings=$ph_count"
