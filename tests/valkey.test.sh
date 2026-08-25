#!/usr/bin/env bash

# shellcheck disable=SC1091
set -euo pipefail

ROOT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/helpers.sh"

trap cleanup_mise EXIT
setup_mise

version="$(tool_version valkey)"
prepare_release valkey "$version" valkey-server valkey-cli redis-server redis-cli
versions="$(run_mise ls-remote db:valkey)"
major="${version%%.*}"

assert_line "$version" <<<"$versions"
[[ "$(run_mise latest "db:valkey@$major")" == "$version" ]]

install_tool valkey "$version"

for command_name in valkey-server valkey-cli redis-server redis-cli; do
  [[ -x "$(run_mise where "db:valkey@$version")/bin/$command_name" ]]
done

output="$(run_tool valkey "$version" valkey-server --version)"
assert_include "$version" "$output"
printf '%s\n' "$output"
