#!/usr/bin/env bash

# shellcheck disable=SC1091,SC2155
set -euo pipefail

ADAPTERS=(apple docker)
INSTALL_DIRS=()
ROOT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

source "$ROOT_DIR/tests/helpers.sh"

cleanup() {
  local adapter="${1}"
  local install_dir
  for install_dir in "${INSTALL_DIRS[@]:-}"; do
    run "$adapter" "$install_dir" redis-server stop >/dev/null 2>&1 || true
  done
}

setup() {
  export _MISE_DB_REDIS_FAMILY=7.4
  export _MISE_DB_REDIS_IMAGE=redis:7.4-alpine
  export _MISE_DB_REDIS_NAME=smoke
  export _MISE_DB_REDIS_VERSION=7.4
  local adapter="${1}"
  local install_dir="$(install_tool redis 7.4 "$adapter")"

  INSTALL_DIRS+=("$install_dir")
  install_wrapper "$ROOT_DIR" "$install_dir" redis redis-server redis-cli

  [[ -x "$install_dir/bin/redis-server" ]]
  [[ -x "$install_dir/bin/redis-cli" ]]
}

activation_state_test() {
  local install_dir="${INSTALL_DIRS[$((${#INSTALL_DIRS[@]} - 1))]}"
  local output status

  capture output status env -u _MISE_DB_REDIS_IMAGE PATH="$install_dir/bin:$PATH" MISE_DB_ADAPTER=docker redis-server status
  assert_equal 1 "$status"
  assert_include "_MISE_DB_REDIS_IMAGE is required" "$output"
  assert_include "activated mise environment" "$output"

  capture output status env PATH="$install_dir/bin:$PATH" MISE_DB_ADAPTER=invalid redis-server status
  assert_equal 1 "$status"
  assert_include "MISE_DB_ADAPTER must be set to 'apple' or 'docker'" "$output"
}

versions_test() {
  local cache_dir output

  cache_dir="$(create_cache "$ROOT_DIR" redis)"
  output="$(MISE_DB_ADAPTER=docker XDG_CACHE_HOME="$cache_dir" mise ls-remote mise-db:redis)"

  assert_line 7.4 <<<"$output"
  assert_line 7.4.2 <<<"$output"
  refute 5.0.14 <<<"$output"
  refute 7 <<<"$output"
  refute 8.0-rc1 <<<"$output"
  refute 8.0.1-alpine3.21 <<<"$output"
  refute 9.0 <<<"$output"

  assert_equal 7.4.2 "$(MISE_DB_ADAPTER=docker XDG_CACHE_HOME="$cache_dir" mise latest mise-db:redis@7)"
}

service_test() {
  local adapter="${1}"
  local install_dir="${INSTALL_DIRS[$((${#INSTALL_DIRS[@]} - 1))]}"

  run "$adapter" "$install_dir" redis-cli --help >/dev/null
  run "$adapter" "$install_dir" redis-cli --version | grep -F 'redis-cli' >/dev/null

  run "$adapter" "$install_dir" redis-server start
  run "$adapter" "$install_dir" redis-server status
  assert_equal PONG "$(run "$adapter" "$install_dir" redis-cli --raw ping)"
  assert_equal OK "$(run "$adapter" "$install_dir" redis-cli --raw set mise-db:persistence survived)"
  assert_equal survived "$(run "$adapter" "$install_dir" redis-cli --raw get mise-db:persistence)"
}

versions_test

for adapter in "${ADAPTERS[@]}"; do
  if ! adapter_available "$adapter"; then
    echo "===================================================================="
    echo "= Skipping Redis tests for ${adapter} adapter - not available"
    echo "===================================================================="
    continue
  else
    echo "===================================================================="
    echo "= Running Redis tests with ${adapter} adapter"
    echo "===================================================================="
  fi

  trap 'cleanup "$adapter"' EXIT

  setup "$adapter"
  activation_state_test
  service_test "$adapter"
  cleanup "$adapter"
  trap - EXIT
done
