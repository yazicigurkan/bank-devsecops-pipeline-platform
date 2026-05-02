#!/usr/bin/env bash
set -euo pipefail

base_url="$1"
token="$2"
project_key="$3"
repository="$4"
branch="$5"
commit_sha="$6"
previous_commit_sha="${7:-}"
environment="${8:-DEV}"
jira_issue_key="${9:-}"
fail_on_high="${10:-true}"
scan_type="${11:-incremental}"

endpoint="incremental-scan"
if [ "$scan_type" = "full" ]; then
  endpoint="full-scan"
fi

payload=$(jq -n \
  --arg repository "$repository" \
  --arg branch "$branch" \
  --arg commitSha "$commit_sha" \
  --arg previousCommitSha "$previous_commit_sha" \
  --arg environment "$environment" \
  --arg jiraIssueKey "$jira_issue_key" \
  '{repository:$repository,branch:$branch,commitSha:$commitSha,previousCommitSha:$previousCommitSha,environment:$environment,jiraIssueKey:$jiraIssueKey}')

curl -fsS -X POST \
  -H "Authorization: Bearer ${token}" \
  -H "Content-Type: application/json" \
  -d "$payload" \
  "${base_url}/api/projects/${project_key}/${endpoint}" \
  -o graphnode-result.json

critical=$(jq -r '.critical // 0' graphnode-result.json)
high=$(jq -r '.high // 0' graphnode-result.json)

if [ "$critical" -gt 0 ]; then
  echo "GraphNode critical findings: $critical" >&2
  exit 1
fi

if [ "$high" -gt 0 ] && [ "$fail_on_high" = "true" ]; then
  echo "GraphNode high findings: $high" >&2
  exit 1
fi

jq -r '.reportUrl' graphnode-result.json
