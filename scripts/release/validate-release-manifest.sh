#!/usr/bin/env bash
set -euo pipefail

manifest_path="$1"
expected_application="$2"
expected_version="$3"
expected_jira_issue="$4"
deployment_type="$5"

fail() {
  echo "Release manifest validation failed: $1" >&2
  exit 1
}

require_json_value() {
  local jq_filter="$1"
  local expected="$2"
  local label="$3"
  local actual
  actual="$(jq -r "$jq_filter" "$manifest_path")"
  [ "$actual" = "$expected" ] || fail "$label expected=$expected actual=$actual"
}

[ -f "$manifest_path" ] || fail "manifest not found: $manifest_path"
require_json_value '.application' "$expected_application" "application"
require_json_value '.version' "$expected_version" "version"
require_json_value '.jiraIssueKey' "$expected_jira_issue" "jiraIssueKey"
require_json_value '.testDeployment.status' "APPROVED" "testDeployment.status"
require_json_value '.sonarQualityGate' "PASSED" "sonarQualityGate"
require_json_value '.graphNode.critical // 0 | tostring' "0" "graphNode.critical"
require_json_value '.graphNode.high // 0 | tostring' "0" "graphNode.high"
require_json_value '.twistlock.critical // 0 | tostring' "0" "twistlock.critical"
require_json_value '.twistlock.high // 0 | tostring' "0" "twistlock.high"

case "$deployment_type" in
  iis)
    [ "$(jq -r '.artifactUrl // empty' "$manifest_path")" != "" ] || fail "artifactUrl missing"
    ;;
  kubernetes)
    [ "$(jq -r '.imageDigest // empty' "$manifest_path")" != "" ] || fail "imageDigest missing"
    [ "$(jq -r '.imageTag // empty' "$manifest_path")" != "" ] || fail "imageTag missing"
    ;;
  *)
    fail "unsupported deployment_type=$deployment_type"
    ;;
esac

echo "Release manifest validation passed: $manifest_path"
