#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "usage: $0 <tool> <version> <target>" >&2
}

write_exists() {
  exists="$1"

  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "exists=$exists" >> "$GITHUB_OUTPUT"
  else
    echo "$exists"
  fi
}

if [ "$#" -ne 3 ]; then
  usage
  exit 2
fi

tool="$1"
version="$2"
target="$3"
tag="$tool-$version"
archive="$tool-$version-$target.tar.xz"
checksum="$archive.sha256"
assets="$(mktemp)"
trap 'rm -f "$assets"' EXIT

if gh release view "$tag" --json assets --jq '.assets[].name' > "$assets" 2>/dev/null; then
  if grep -Fx "$archive" "$assets" >/dev/null && grep -Fx "$checksum" "$assets" >/dev/null; then
    write_exists true
    echo "$archive and $checksum already exist in $tag"
  else
    write_exists false
  fi
else
  write_exists false
fi
