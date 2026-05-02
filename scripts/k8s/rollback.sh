#!/usr/bin/env bash
set -euo pipefail

release_name="$1"
namespace="$2"
revision="${3:-0}"

if [ "$revision" = "0" ]; then
  helm rollback "$release_name" --namespace "$namespace" --wait --timeout 10m
else
  helm rollback "$release_name" "$revision" --namespace "$namespace" --wait --timeout 10m
fi

kubectl rollout status "deployment/${release_name}" -n "$namespace" --timeout=300s

