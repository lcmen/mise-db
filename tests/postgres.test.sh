#!/usr/bin/env bash

# shellcheck disable=SC1091,SC2155
set -euo pipefail

readonly ROOT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/helpers.sh"

cleanup() {
  local install_dir
  for install_dir in "${INSTALL_DIRS[@]:-}"; do
    run "$install_dir" "$install_dir/bin/pg_ctl" stop >/dev/null 2>&1 || true
  done
}

run_adapter_test() {
  local adapter="${1}"
  local install_dir

  install_dir="$(install_tool postgres 18.4 true "$adapter")"
  INSTALL_DIRS+=("$install_dir")
  install_wrapper "$ROOT_DIR" "$install_dir" postgres pg_ctl psql

  run "$install_dir" "$install_dir/bin/pg_ctl" start
  run "$install_dir" "$install_dir/bin/pg_ctl" status
  run "$install_dir" "$install_dir/bin/psql" -d postgres -c 'select 1 as ok;'
}

INSTALL_DIRS=()
readonly -a ADAPTERS=(apple docker)

trap cleanup EXIT

for adapter in "${ADAPTERS[@]}"; do
  if ! adapter_available "$adapter"; then
    echo "required test adapter is not available: $adapter" >&2
    exit 1
  fi
  run_adapter_test "$adapter"
done
