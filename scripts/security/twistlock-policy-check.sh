#!/usr/bin/env bash
set -euo pipefail

result_file="$1"
fail_on_high="${2:-true}"

critical=$(jq '[.results[].vulnerabilities[]? | select((.severity | ascii_downcase)=="critical")] | length' "$result_file")
high=$(jq '[.results[].vulnerabilities[]? | select((.severity | ascii_downcase)=="high")] | length' "$result_file")

if [ "$critical" -gt 0 ]; then
  echo "Critical vulnerabilities: $critical" >&2
  exit 1
fi

if [ "$high" -gt 0 ] && [ "$fail_on_high" = "true" ]; then
  echo "High vulnerabilities: $high" >&2
  exit 1
fi

echo "Twistlock policy passed. critical=$critical high=$high"
