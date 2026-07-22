#!/usr/bin/env bash

# shellcheck disable=SC1091,SC2155
set -euo pipefail

readonly -a ADAPTERS=(apple docker)
INSTALL_DIRS=()
readonly ROOT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/helpers.sh"

cleanup() {
  local adapter="${1}"
  local install_dir
  for install_dir in "${INSTALL_DIRS[@]:-}"; do
    PGUSER=postgres PGPASSWORD=postgres run "$adapter" "$install_dir" "$install_dir/bin/pg_ctl" stop >/dev/null 2>&1 || true
  done
}

versions_test() {
  local adapter="${1}"
  local cache_dir output

  cache_dir="$(create_cache "$ROOT_DIR" postgres)"
  output="$(MISE_DB_ADAPTER="$adapter" XDG_CACHE_HOME="$cache_dir" mise ls-remote db:postgres)"

  assert 12 <<<"$output"
  assert 13 <<<"$output"
  assert 18 <<<"$output"
  assert 18.4 <<<"$output"
  refute 18.4-alpine3.22 <<<"$output"
}

service_test() {
  local adapter="${1}"
  local install_dir

  install_dir="$(install_tool postgres 18.4 true "$adapter")"
  INSTALL_DIRS+=("$install_dir")
  install_wrapper "$ROOT_DIR" "$install_dir" postgres pg_ctl psql

  PGUSER=postgres PGPASSWORD=postgres run "$adapter" "$install_dir" "$install_dir/bin/pg_ctl" start
  PGUSER=postgres PGPASSWORD=postgres run "$adapter" "$install_dir" "$install_dir/bin/pg_ctl" status
  PGUSER=postgres PGPASSWORD=postgres run "$adapter" "$install_dir" "$install_dir/bin/psql" -d postgres -c 'select 1 as ok;'
}

for adapter in "${ADAPTERS[@]}"; do
  if ! adapter_available "$adapter"; then
    echo "required test adapter is not available: $adapter" >&2
    exit 1
  fi

  trap 'cleanup "$adapter"' EXIT

  versions_test "$adapter"
  service_test "$adapter"
  cleanup "$adapter"
  trap - EXIT
done
