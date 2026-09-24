#!/usr/bin/env bash

set -euo pipefail

#######################################
# Builds the deterministic Docker container name.
# Globals:
#   TOOL
# Arguments:
#   $1: Name.
#   $2: Compatibility family.
# Outputs:
#   Container name.
# Returns:
#   0.
#######################################
container_name() {
  local name="${1:?name is required}"
  local family="${2:?family is required}"
  local tool="${TOOL:?TOOL is required}"
  printf 'mise-db-%s-%s-%s\n' "$tool" "$(version_tag "$family")" "$name"
}

#######################################
# Builds the persistent host data directory path.
# Globals:
#   HOME
#   TOOL
#   XDG_DATA_HOME
# Arguments:
#   $1: Name.
#   $2: Compatibility family.
# Outputs:
#   Data directory path.
# Returns:
#   0.
#######################################
data_dir() {
  local name="${1:?name is required}"
  local family="${2:?family is required}"
  local base="${XDG_DATA_HOME:-$HOME/.local/share}"
  printf '%s/mise-db/%s/%s/%s\n' "$base" "$TOOL" "$family" "$name"
}

#######################################
# Converts a version string into a Docker-name-safe tag segment.
# Globals:
#   VERSION
# Arguments:
#   $1: Version string. Defaults to VERSION.
# Outputs:
#   Sanitized version tag.
# Returns:
#   0.
#######################################
version_tag() {
  local version="${1:-${VERSION:-}}"
  printf '%s' "$version" | sed -E 's/[^A-Za-z0-9]+/-/g; s/^-+//; s/-+$//'
}
