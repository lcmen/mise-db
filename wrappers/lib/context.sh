#!/usr/bin/env bash

set -euo pipefail

#######################################
# Computes a small deterministic checksum for a string.
# Arguments:
#   $1: Input string.
# Outputs:
#   Decimal checksum in the range 0..65535.
# Returns:
#   0.
#######################################
byte_sum() {
  local value="${1:-}"
  local sum=0
  local byte

  for byte in $(printf '%s' "$value" | od -An -tu1 -v); do
    sum=$(( (sum + byte) % 65536 ))
  done

  printf '%s\n' "$sum"
}

#######################################
# Builds the deterministic Docker container name.
# Globals:
#   TOOL
#   VERSION
#   ISOLATED
# Outputs:
#   Container name.
# Returns:
#   0.
#######################################
container_name() {
  printf 'mise-db-%s-%s-%s\n' "$TOOL" "$(version_tag "$VERSION")" "$(instance_name "$TOOL")"
}

#######################################
# Builds the persistent host data directory path.
# Globals:
#   HOME
#   ISOLATED
#   TOOL
#   VERSION
#   XDG_DATA_HOME
# Outputs:
#   Data directory path.
# Returns:
#   0.
#######################################
data_dir() {
  local base="${XDG_DATA_HOME:-$HOME/.local/share}"
  printf '%s/mise-db/%s/%s/%s\n' "$base" "$TOOL" "$VERSION" "$(instance_name "$TOOL")"
}

#######################################
# Builds the instance identity for global or isolated mode.
# Globals:
#   ISOLATED
#   TOOL
# Arguments:
#   $1: Tool name. Defaults to TOOL.
# Outputs:
#   "global" or "<project-slug>-<path-checksum>".
# Returns:
#   0.
#######################################
instance_name() {
  local tool="${1:-${TOOL:?TOOL is required}}"
  local isolated="${ISOLATED:-false}"

  if [[ "$isolated" == "true" ]]; then
    local root slug sum
    root="$(project_root)"
    slug="$(sanitize "$(basename "$root")")"
    sum="$(byte_sum "$root")"
    printf '%s-%04x\n' "$slug" "$sum"
  else
    printf 'global\n'
  fi
}

#######################################
# Finds the current project root used for isolated identities.
# Globals:
#   MISE_PROJECT_ROOT
# Outputs:
#   MISE_PROJECT_ROOT, git root, or current physical directory.
# Returns:
#   0.
#######################################
project_root() {
  if [[ -n "${MISE_PROJECT_ROOT:-}" ]]; then
    printf '%s\n' "$MISE_PROJECT_ROOT"
    return
  fi

  if command -v git >/dev/null 2>&1; then
    git rev-parse --show-toplevel 2>/dev/null && return
  fi

  pwd -P
}

#######################################
# Converts arbitrary text into a lowercase slug.
# Arguments:
#   $1: Input string. Defaults to "project".
# Outputs:
#   Slug containing only lowercase letters, digits, and hyphens.
# Returns:
#   0.
#######################################
sanitize() {
  local value="${1:-project}"
  value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
  if [[ -z "$value" ]]; then
    printf 'project\n'
  else
    printf '%s\n' "$value"
  fi
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
