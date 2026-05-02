#!/usr/bin/env bash
set -euo pipefail

release_name="$1"
namespace="$2"
chart_path="$3"
values_file="$4"
image_repository="$5"
image_tag="$6"
health_check_url="$7"

helm upgrade --install "$release_name" "$chart_path" \
  --namespace "$namespace" --create-namespace \
  --values "$values_file" \
  --set image.repository="$image_repository" \
  --set image.tag="$image_tag" \
  --wait --timeout 10m

kubectl rollout status "deployment/${release_name}" -n "$namespace" --timeout=300s
curl -fsS --retry 12 --retry-delay 10 "$health_check_url"

