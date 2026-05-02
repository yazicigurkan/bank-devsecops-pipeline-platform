#!/usr/bin/env bash
set -euo pipefail

artifact_url="$1"
output_path="$2"
username="$3"
password="$4"

curl -fsS -u "${username}:${password}" -o "$output_path" "$artifact_url"

