#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 <tool> <archive>" >&2
}

if [ "$#" -ne 2 ]; then
  usage
  exit 2
fi

tool="$1"
archive="$2"

case "$tool" in
  postgres) ;;
  *) echo "unsupported tool: $tool" >&2; exit 1 ;;
esac

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

tar -xf "$archive" -C "$tmp_dir"

"$tmp_dir/bin/postgres" --version
"$tmp_dir/bin/psql" --version
"$tmp_dir/bin/initdb" --version
