#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  simulate-pipeline.sh dev
  simulate-pipeline.sh test
  simulate-pipeline.sh prod
  simulate-pipeline.sh negative
  simulate-pipeline.sh all

This script is a local dry-run harness. It does not call Jira, Nexus, Harbor,
SonarQube, GraphNode, Twistlock, IIS or Kubernetes. It verifies the platform
governance model with local mock evidence.
USAGE
}

mode="${1:-all}"
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
lab_dir="${root_dir}/local-lab"
nexus_dir="${lab_dir}/mock-nexus"
harbor_dir="${lab_dir}/mock-harbor"
jira_dir="${lab_dir}/mock-jira"
evidence_dir="${lab_dir}/evidence"

application="payment-api"
version="1.4.2"
commit_sha="abc1234"
run_number="145"
jira_issue="SDLC-1234"
test_tag="${version}-TEST-${commit_sha}-${run_number}"
prod_tag="${version}-PROD-${commit_sha}-${run_number}"
artifact_version="${version}-TEST-${commit_sha}-${run_number}"
artifact_url="${nexus_dir}/dotnet-releases/${application}/${artifact_version}/${application}.zip"
image_ref="harbor.bank.local/payment/${application}:${test_tag}"
if command -v shasum >/dev/null 2>&1; then
  image_digest="sha256:$(printf '%s' "${image_ref}" | shasum -a 256 | awk '{print $1}')"
else
  image_digest="sha256:$(printf '%s' "${image_ref}" | sha256sum | awk '{print $1}')"
fi

reset_lab() {
  rm -rf "$lab_dir"
  mkdir -p "$nexus_dir/dotnet-releases/${application}/${artifact_version}" "$harbor_dir/payment/${application}" "$jira_dir" "$evidence_dir"
}

write_jira_issue() {
  local status="$1"
  local manager="$2"
  local security="$3"
  local test_approval="$4"
  jq -n \
    --arg key "$jira_issue" \
    --arg status "$status" \
    --arg manager "$manager" \
    --arg security "$security" \
    --arg testApproval "$test_approval" \
    --arg changeWindow "2026-05-02T21:00:00+03:00/2026-05-02T23:00:00+03:00" \
    --arg rollbackPlan "Use approved Nexus artifact for IIS or Helm rollback for Kubernetes." \
    '{key:$key,status:$status,managerApproval:$manager,securityApproval:$security,testApproval:$testApproval,changeWindow:$changeWindow,rollbackPlan:$rollbackPlan}' \
    > "${jira_dir}/${jira_issue}.json"
}

require_jira() {
  local expected_status="$1"
  local require_security="$2"
  local issue_file="${jira_dir}/${jira_issue}.json"
  test -f "$issue_file"
  local status
  status="$(jq -r '.status' "$issue_file")"
  if [ "$status" != "$expected_status" ]; then
    echo "Jira status invalid. expected=${expected_status} actual=${status}" >&2
    exit 1
  fi
  test "$(jq -r '.managerApproval' "$issue_file")" = "Approved"
  test "$(jq -r '.testApproval' "$issue_file")" = "Approved"
  if [ "$require_security" = "true" ]; then
    test "$(jq -r '.securityApproval' "$issue_file")" = "Approved"
    test "$(jq -r '.changeWindow' "$issue_file")" != ""
    test "$(jq -r '.rollbackPlan' "$issue_file")" != ""
  fi
}

require_file() {
  local path="$1"
  if [ ! -f "$path" ]; then
    echo "Required file not found: ${path}" >&2
    return 1
  fi
}

simulate_dev() {
  echo "[DEV] restore/test/sonar/graphnode/build/package"
  mkdir -p "${evidence_dir}/dev"
  jq -n \
    --arg application "$application" \
    --arg environment "DEV" \
    --arg sonarQualityGate "PASSED" \
    --arg graphNodeScanId "scan-dev-001" \
    --arg createdAt "$(date -Iseconds)" \
    '{application:$application,environment:$environment,sonarQualityGate:$sonarQualityGate,graphNode:{scanId:$graphNodeScanId,critical:0,high:0},createdAt:$createdAt}' \
    > "${evidence_dir}/dev/deployment-evidence.json"
  echo "[DEV] evidence=${evidence_dir}/dev/deployment-evidence.json"
}

simulate_test() {
  echo "[TEST] Jira validation"
  write_jira_issue "TEST Deploy Approved" "Approved" "Not Required" "Approved"
  require_jira "TEST Deploy Approved" false

  echo "[TEST] build once and publish release candidate"
  printf 'mock package for %s %s\n' "$application" "$artifact_version" > "$artifact_url"
  printf '%s\n' "$image_digest" > "${harbor_dir}/payment/${application}/${test_tag}.digest"

  jq -n \
    --arg application "$application" \
    --arg version "$version" \
    --arg commitSha "$commit_sha" \
    --arg artifactUrl "$artifact_url" \
    --arg image "$image_ref" \
    --arg imageTag "$test_tag" \
    --arg imageDigest "$image_digest" \
    --arg jiraIssueKey "$jira_issue" \
    --arg createdAt "$(date -Iseconds)" \
    '{application:$application,version:$version,commitSha:$commitSha,artifactUrl:$artifactUrl,image:$image,imageTag:$imageTag,imageDigest:$imageDigest,sonarQualityGate:"PASSED",graphNode:{scanId:"scan-9876",critical:0,high:0},twistlock:{scanId:"tw-1234",critical:0,high:0},jiraIssueKey:$jiraIssueKey,approvedBy:["manager.user"],testApprovedBy:"test.user",testDeployment:{environment:"TEST",status:"APPROVED"},rollbackPlan:"Nexus artifact rollback or Helm rollback to previous revision",createdAt:$createdAt}' \
    > "${evidence_dir}/release-manifest.json"

  echo "[TEST] artifact=${artifact_url}"
  echo "[TEST] imageDigest=${image_digest}"
  echo "[TEST] manifest=${evidence_dir}/release-manifest.json"
}

simulate_prod() {
  echo "[PROD] Jira, change window, rollback plan and release evidence validation"
  write_jira_issue "DevOps Deploy Bekliyor" "Approved" "Approved" "Approved"
  require_jira "DevOps Deploy Bekliyor" true

  local manifest="${evidence_dir}/release-manifest.json"
  "${root_dir}/scripts/release/validate-release-manifest.sh" "$manifest" "$application" "$version" "$jira_issue" "kubernetes" >/dev/null || return 1
  require_file "$(jq -r '.artifactUrl' "$manifest")" || return 1

  echo "[PROD] rebuild is blocked by design; promoting approved TEST evidence only"
  jq --arg prodTag "$prod_tag" '.prodPromotion={imageTag:$prodTag,promotionType:"digest-preserving",rebuilt:false}' "$manifest" \
    > "${evidence_dir}/prod-deployment-evidence.json"

  echo "[PROD] promotedTag=${prod_tag}"
  echo "[PROD] evidence=${evidence_dir}/prod-deployment-evidence.json"
}

simulate_negative() {
  reset_lab
  simulate_dev
  simulate_test

  echo "[NEGATIVE] tampering release manifest with Twistlock high vulnerability"
  jq '.twistlock.high=1' "${evidence_dir}/release-manifest.json" > "${evidence_dir}/release-manifest.tampered.json"
  mv "${evidence_dir}/release-manifest.tampered.json" "${evidence_dir}/release-manifest.json"

  set +e
  simulate_prod >/tmp/bank-pipeline-negative.out 2>/tmp/bank-pipeline-negative.err
  local rc=$?
  set -e

  if [ "$rc" -eq 0 ]; then
    echo "[NEGATIVE] expected PROD validation failure, but promotion succeeded" >&2
    cat /tmp/bank-pipeline-negative.out >&2
    exit 1
  fi

  echo "[NEGATIVE] PROD promotion blocked as expected"
  cat /tmp/bank-pipeline-negative.err
}

case "$mode" in
  dev)
    reset_lab
    simulate_dev
    ;;
  test)
    reset_lab
    simulate_dev
    simulate_test
    ;;
  prod)
    reset_lab
    simulate_dev
    simulate_test
    simulate_prod
    ;;
  all)
    reset_lab
    simulate_dev
    simulate_test
    simulate_prod
    ;;
  negative)
    simulate_negative
    ;;
  *)
    usage
    exit 2
    ;;
esac

echo "[OK] local dry-run completed in ${lab_dir}"
