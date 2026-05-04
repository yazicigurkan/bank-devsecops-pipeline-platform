#!/usr/bin/env bash
set -euo pipefail

version="${1:?release version is required}"

fail() {
  echo "Invalid release_version='${version}': $1" >&2
  exit 1
}

[ "${#version}" -le 128 ] || fail "Docker tags must be 128 characters or fewer"

case "$version" in
  ""|.*|-*|*/*|*\\*|*:*|*' '*|*..*)
    fail "use a SemVer-like Docker/Nexus-safe value, for example v1.1.1 or v1.1.1-rc.1"
    ;;
esac

if [[ ! "$version" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z][0-9A-Za-z.-]*)?$ ]]; then
  fail "expected vMAJOR.MINOR.PATCH or vMAJOR.MINOR.PATCH-prerelease"
fi
