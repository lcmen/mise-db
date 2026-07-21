#!/usr/bin/env bash
# shellcheck shell=bash

#######################################
# Creates a temporary install directory for a tool smoke test.
# Arguments:
#   $1: Tool name.
# Outputs:
#   Temporary install directory path.
# Returns:
#   0 after the directory is created.
#######################################
create_dir() {
  local tool="${1:?tool is required}"
  mktemp -d "/tmp/mise-db-${tool}-test.XXXXXX"
}

#######################################
# Installs a wrapper and command symlinks into a temporary install tree.
# Arguments:
#   $1: Repository root.
#   $2: Temporary install directory.
#   $3: Wrapper name.
#   $@: Command names to symlink to the wrapper.
# Returns:
#   0 after the wrapper install tree is created.
#######################################
install_wrapper() {
  local root="${1:?repo root is required}"
  local install_dir="${2:?install dir is required}"
  local wrapper="${3:?wrapper name is required}"
  shift 3

  mkdir -p "$install_dir/bin"
  cp -R "$root/wrappers/lib" "$install_dir"
  cp "$root/wrappers/$wrapper" "$install_dir/lib/$wrapper"
  chmod -R u+rwX "$install_dir"
  find "$install_dir/lib" -type f -exec chmod 755 {} +

  local command_name
  for command_name in "$@"; do
    ln -sf "$install_dir/lib/$wrapper" "$install_dir/bin/$command_name"
  done
}

adapter_available() {
  local adapter="${1:?adapter is required}"

  case "$adapter" in
    apple)
      command -v container >/dev/null 2>&1 && container system status >/dev/null 2>&1
      ;;
    docker)
      command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1
      ;;
    *)
      echo "unsupported test adapter: $adapter" >&2
      return 2
      ;;
  esac
}

adapter_pull() {
  local adapter="${1:?adapter is required}"
  local image="${2:?image is required}"

  case "$adapter" in
    apple)
      container image inspect "$image" >/dev/null 2>&1 || container image pull "$image" >&2
      ;;
    docker)
      docker image inspect "$image" >/dev/null 2>&1 || docker pull "$image" >&2
      ;;
  esac
}

#######################################
# Creates a temporary install directory and writes its manifest.
# Arguments:
#   $1: Tool name.
#   $2: Tool version.
#   $3: Isolated mode, true or false.
#   $4: Adapter, docker or apple.
# Outputs:
#   Temporary install directory path.
# Returns:
#   0 after the directory and manifest are created.
#######################################
install_tool() {
  local tool="${1:?tool is required}"
  local version="${2:?version is required}"
  local isolated="${3:?isolated is required}"
  local adapter="${4:?adapter is required}"
  local install_dir image

  install_dir="$(create_dir "$tool")"
  image="${tool}:${version}-alpine"

  adapter_pull "$adapter" "$image"

  cat >"$install_dir/manifest" <<EOF
TOOL=$tool
VERSION=$version
IMAGE=$image
ISOLATED=$isolated
ADAPTER=$adapter
EOF

  printf '%s\n' "$install_dir"
}

#######################################
# Runs a command with mise-db test environment variables.
# Arguments:
#   $1: Temporary install directory.
#   $@: Command and arguments to execute.
# Returns:
#   The wrapped command's exit status.
#######################################
run() {
  local install_dir="${1:?install dir is required}"
  shift

  MISE_PROJECT_ROOT="$install_dir" XDG_DATA_HOME="$install_dir/data" \
    PGUSER=postgres PGPASSWORD=postgres "$@"
}
