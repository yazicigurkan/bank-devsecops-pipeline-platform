#!/usr/bin/env bash
set -euo pipefail

base_url="$1"
user_email="$2"
api_token="$3"
issue_key="$4"
comment="$5"

jq -n --arg body "$comment" \
  '{body:{type:"doc",version:1,content:[{type:"paragraph",content:[{type:"text",text:$body}]}]}}' \
  > jira-comment.json

curl -fsS -u "${user_email}:${api_token}" \
  -H "Content-Type: application/json" \
  -X POST \
  -d @jira-comment.json \
  "${base_url}/rest/api/3/issue/${issue_key}/comment"

