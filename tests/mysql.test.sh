#!/usr/bin/env bash

# shellcheck disable=SC1091
set -euo pipefail

ROOT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/helpers.sh"

trap cleanup_mise EXIT
setup_mise

version="$(tool_version mysql)"
prepare_release mysql "$version" mysqld mysql mysqladmin mysqldump
versions="$(run_mise ls-remote db:mysql)"
family="${version%.*}"

assert_line "$version" <<<"$versions"
[[ "$(run_mise latest "db:mysql@$family")" == "$version" ]]

install_tool mysql "$version"

for command_name in mysqld mysql mysqladmin mysqldump; do
  [[ -x "$(run_mise where "db:mysql@$version")/bin/$command_name" ]]
done

output="$(run_tool mysql "$version" mysqld --version)"
assert_include "$version" "$output"
printf '%s\n' "$output"
