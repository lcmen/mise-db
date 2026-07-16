#!/usr/bin/env bash

# shellcheck disable=SC1091,SC2155
set -euo pipefail

readonly ROOT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/helpers.sh"

setup() {
  readonly TMPDIR="$(install_tool postgres 18.4 true)"

  install_wrapper "$ROOT_DIR" "$TMPDIR" postgres \
    pg_ctl \
    psql
}

cleanup() {
  run "$TMPDIR" "$TMPDIR/bin/pg_ctl" stop >/dev/null 2>&1 || true
}

test_postgres() {
  run "$TMPDIR" "$TMPDIR/bin/pg_ctl" start
  run "$TMPDIR" "$TMPDIR/bin/pg_ctl" status
  run "$TMPDIR" "$TMPDIR/bin/psql" -d postgres -c 'select 1 as ok;'
  run "$TMPDIR" "$TMPDIR/bin/pg_ctl" stop
}

trap cleanup EXIT
setup
test_postgres
