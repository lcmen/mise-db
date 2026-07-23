#!/usr/bin/env bash

# shellcheck disable=SC1091,SC2155
set -euo pipefail

ADAPTERS=(apple docker)
INSTALL_DIRS=()
ROOT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

source "$ROOT_DIR/tests/helpers.sh"

setup() {
  export PGPASS=postgres
  export PGUSER=postgres
  local adapter="${1}"
  local install_dir="$(install_tool postgres 18.4 true "$adapter")"

  INSTALL_DIRS+=("$install_dir")
  install_wrapper "$ROOT_DIR" "$install_dir" postgres pg_ctl psql pg_dump pg_restore
}

cleanup() {
  local adapter="${1}"
  local install_dir
  for install_dir in "${INSTALL_DIRS[@]:-}"; do
    run "$adapter" "$install_dir" pg_ctl stop >/dev/null 2>&1 || true
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
  local install_dir="${INSTALL_DIRS[$((${#INSTALL_DIRS[@]} - 1))]}"
  local dump_file="$ROOT_DIR/tests/tmp/dump.sql"

  rm -f "$dump_file"
  run "$adapter" "$install_dir" pg_ctl start
  run "$adapter" "$install_dir" pg_ctl status
  run "$adapter" "$install_dir" psql -c 'select 1 as ok;'
  run "$adapter" "$install_dir" psql --set ON_ERROR_STOP=1 <"$ROOT_DIR/tests/fixtures/dump.sql"
  run "$adapter" "$install_dir" psql --set ON_ERROR_STOP=1 -c 'drop table mise_db_restore_fixture;'
  run "$adapter" "$install_dir" pg_dump --format=custom --file "$dump_file" postgres
  run "$adapter" "$install_dir" pg_restore --dbname postgres "$dump_file"
}

for adapter in "${ADAPTERS[@]}"; do
  if ! adapter_available "$adapter"; then
    echo "===================================================================="
    echo "= Skipping Postgres tests for ${adapter} adapter - not available"
    echo "===================================================================="
    continue
  else
    echo "===================================================================="
    echo "= Running Postgres tests with ${adapter} adapter"
    echo "===================================================================="
  fi

  trap 'cleanup "$adapter"' EXIT

  setup "$adapter"
  versions_test "$adapter"
  service_test "$adapter"
  cleanup "$adapter"
  trap - EXIT
done
