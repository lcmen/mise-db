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
# Creates a temporary cache directory with registry fixtures.
# Arguments:
#   $1: Repository root.
#   $2: Service name.
# Outputs:
#   Temporary XDG cache home path.
# Returns:
#   0 after the cache fixture is copied.
#######################################
create_cache() {
  local root="${1:?repo root is required}"
  local service="${2:?service is required}"
  local cache_dir

  cache_dir="$(mktemp -d "/tmp/mise-db-cache-test.XXXXXX")"
  mkdir -p "$cache_dir/mise-db"
  cp "$root/tests/fixtures/$service.json" "$cache_dir/mise-db/$service.json"

  printf '%s\n' "$cache_dir"
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
# Captures a command's combined output and exit status.
# Arguments:
#   $1: Variable name that receives combined stdout and stderr.
#   $2: Variable name that receives the exit status.
#   Remaining arguments: Command and arguments to run.
# Returns:
#   0 after assigning both variables.
#######################################
capture() {
  local output_var="${1:?output variable is required}"
  local status_var="${2:?status variable is required}"
  shift 2
  local captured_status captured_output

  if captured_output="$("$@" 2>&1)"; then
    captured_status=0
  else
    captured_status=$?
  fi

  printf -v "$output_var" '%s' "$captured_output"
  printf -v "$status_var" '%s' "$captured_status"
}

#######################################
# Asserts that two values are equal.
# Arguments:
#   $1: Expected value.
#   $2: Actual value.
# Returns:
#   0 when the values are equal; 1 otherwise.
#######################################
assert_equal() {
  local expected="${1-}"
  local actual="${2-}"

  if [[ "$actual" != "$expected" ]]; then
    echo "expected '$expected', got '$actual'" >&2
    return 1
  fi
}

#######################################
# Asserts that text contains a substring.
# Arguments:
#   $1: Expected substring.
#   $2: Text to search.
# Returns:
#   0 when the substring is present; 1 otherwise.
#######################################
assert_include() {
  local expected="${1:?expected text is required}"
  local actual="${2-}"

  if [[ "$actual" != *"$expected"* ]]; then
    echo "expected text to include: $expected" >&2
    return 1
  fi
}

#######################################
# Asserts that stdin contains an exact line.
# Arguments:
#   $1: Expected line.
# Returns:
#   0 when stdin contains the line; exits with an error otherwise.
#######################################
assert_line() {
  local expected="${1:?expected line is required}"

  if ! sed 's/\r$//' | grep -Fx "$expected" >/dev/null; then
    echo "expected output to include: $expected" >&2
    return 1
  fi
}

#######################################
# Refutes that stdin contains an exact line.
# Arguments:
#   $1: Unexpected line.
# Returns:
#   0 when stdin does not contain the line; exits with an error otherwise.
#######################################
refute() {
  local unexpected="${1:?unexpected line is required}"

  if sed 's/\r$//' | grep -Fx "$unexpected" >/dev/null; then
    echo "expected output to exclude: $unexpected" >&2
    return 1
  fi
}

#######################################
# Creates a temporary install directory and pulls its image.
# Arguments:
#   $1: Tool name.
#   $2: Tool version.
#   $3: Adapter, docker or apple.
# Outputs:
#   Temporary install directory path.
# Returns:
#   0 after the directory is created and the image is available.
#######################################
install_tool() {
  local tool="${1:?tool is required}"
  local version="${2:?version is required}"
  local adapter="${3:?adapter is required}"
  local install_dir image

  install_dir="$(create_dir "$tool")"
  image="${tool}:${version}-alpine"

  adapter_pull "$adapter" "$image"

  printf '%s\n' "$install_dir"
}

#######################################
# Runs an installed command with mise-db test environment variables for an adapter.
# Arguments:
#   $1: Adapter, docker or apple.
#   $2: Temporary install directory.
#   $3: Installed command name.
#   $@: Command arguments.
# Returns:
#   The wrapped command's exit status.
#######################################
run() {
  local adapter="${1:?adapter is required}"
  local install_dir="${2:?install dir is required}"
  shift 2

  MISE_DB_ADAPTER="$adapter" PATH="$install_dir/bin:$PATH" XDG_DATA_HOME="$install_dir/data" "$@"
}
