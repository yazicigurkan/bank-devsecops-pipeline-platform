#!/usr/bin/env bash
set -euo pipefail

base_url="$1"
user_email="$2"
api_token="$3"
issue_key="$4"
allowed_statuses="$5"

curl -fsS -u "${user_email}:${api_token}" \
  "${base_url}/rest/api/3/issue/${issue_key}?fields=status" \
  -o jira-issue.json

status=$(jq -r '.fields.status.name' jira-issue.json)
IFS=',' read -ra allowed <<< "$allowed_statuses"
for item in "${allowed[@]}"; do
  if [ "$status" = "$item" ]; then
    echo "$status"
    exit 0
  fi
done

echo "Invalid Jira status '$status'. Allowed: $allowed_statuses" >&2
exit 1

