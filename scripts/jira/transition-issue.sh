#!/usr/bin/env bash
set -euo pipefail

base_url="$1"
user_email="$2"
api_token="$3"
issue_key="$4"
transition_name="$5"

curl -fsS -u "${user_email}:${api_token}" \
  "${base_url}/rest/api/3/issue/${issue_key}/transitions" \
  -o transitions.json

transition_id=$(jq -r --arg name "$transition_name" '.transitions[] | select(.name == $name) | .id' transitions.json | head -1)
if [ -z "$transition_id" ]; then
  echo "Transition not found: $transition_name" >&2
  exit 1
fi

jq -n --arg id "$transition_id" '{transition:{id:$id}}' > transition.json
curl -fsS -u "${user_email}:${api_token}" \
  -H "Content-Type: application/json" \
  -X POST \
  -d @transition.json \
  "${base_url}/rest/api/3/issue/${issue_key}/transitions"

