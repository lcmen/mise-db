#!/usr/bin/env bash

# shellcheck disable=SC1091,SC2155
set -euo pipefail

ADAPTERS=(apple docker)
INSTALL_DIRS=()
ROOT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

source "$ROOT_DIR/tests/helpers.sh"

setup() {
  export _MISE_DB_POSTGRES_FAMILY=18
  export _MISE_DB_POSTGRES_IMAGE=postgres:18.4-alpine
  export _MISE_DB_POSTGRES_NAME=smoke
  export _MISE_DB_POSTGRES_VERSION=18.4
  export PGPASS=postgres
  export PGUSER=postgres
  local adapter="${1}"
  local install_dir="$(install_tool postgres 18.4 "$adapter")"

  INSTALL_DIRS+=("$install_dir")
  install_wrapper "$ROOT_DIR" "$install_dir" postgres pg_ctl psql pg_dump pg_restore
}

activation_state_test() {
  local install_dir="${INSTALL_DIRS[$((${#INSTALL_DIRS[@]} - 1))]}"
  local output status

  capture output status env -u _MISE_DB_POSTGRES_VERSION PATH="$install_dir/bin:$PATH" MISE_DB_ADAPTER=docker pg_ctl status
  assert_equal 1 "$status"
  assert_include "_MISE_DB_POSTGRES_VERSION is required" "$output"
  assert_include "activated mise environment" "$output"

  capture output status env PATH="$install_dir/bin:$PATH" MISE_DB_ADAPTER=invalid pg_ctl status
  assert_equal 1 "$status"
  assert_include "MISE_DB_ADAPTER must be set to 'apple' or 'docker'" "$output"
}

cleanup() {
  local adapter="${1}"
  local install_dir
  for install_dir in "${INSTALL_DIRS[@]:-}"; do
    run "$adapter" "$install_dir" pg_ctl stop >/dev/null 2>&1 || true
  done
}

versions_test() {
  local cache_dir output

  cache_dir="$(create_cache "$ROOT_DIR" postgres)"
  output="$(MISE_DB_ADAPTER=docker XDG_CACHE_HOME="$cache_dir" mise ls-remote mise-db:postgres)"

  assert_line 18.3 <<<"$output"
  assert_line 18.4 <<<"$output"
  refute 11.22 <<<"$output"
  refute 18 <<<"$output"
  refute 18.5-rc1 <<<"$output"
  refute 18.4-alpine3.22 <<<"$output"
  refute 19.1 <<<"$output"

  assert_equal 18.4 "$(MISE_DB_ADAPTER=docker XDG_CACHE_HOME="$cache_dir" mise latest mise-db:postgres@18)"
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

versions_test

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
  activation_state_test
  service_test "$adapter"
  cleanup "$adapter"
  trap - EXIT
done
