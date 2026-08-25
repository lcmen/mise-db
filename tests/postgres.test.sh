#!/usr/bin/env bash

# shellcheck disable=SC1091
set -euo pipefail

ROOT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/helpers.sh"

trap cleanup_mise EXIT
setup_mise

version="$(tool_version postgres)"
prepare_release postgres "$version" postgres pg_ctl initdb psql createdb dropdb createuser dropuser
versions="$(run_mise ls-remote db:postgres)"
major="${version%%.*}"

assert_line "$version" <<<"$versions"
[[ "$(run_mise latest "db:postgres@$major")" == "$version" ]]

install_tool postgres "$version"

for command_name in postgres pg_ctl initdb psql createdb dropdb createuser dropuser; do
  [[ -x "$(run_mise where "db:postgres@$version")/bin/$command_name" ]]
done

output="$(run_tool postgres "$version" postgres --version)"
assert_include "$version" "$output"
printf '%s\n' "$output"
