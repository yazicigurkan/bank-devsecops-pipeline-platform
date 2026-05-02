#!/usr/bin/env bash
set -euo pipefail

nexus_base_url="$1"
repository="$2"
application_name="$3"
artifact_version="$4"
artifact_path="$5"
username="$6"
password="$7"

target="${nexus_base_url}/repository/${repository}/${application_name}/${artifact_version}/${application_name}.zip"
curl -fsS -u "${username}:${password}" --upload-file "$artifact_path" "$target"
echo "$target"

