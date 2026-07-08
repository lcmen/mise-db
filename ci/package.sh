#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 <tool> <version> <target> <prefix> <dist-dir>" >&2
}

if [ "$#" -ne 5 ]; then
  usage
  exit 2
fi

tool="$1"
version="$2"
target="$3"
prefix="$4"
dist_dir="$5"

case "$tool" in
  postgres) ;;
  *) echo "unsupported tool: $tool" >&2; exit 1 ;;
esac

required_bins='postgres pg_ctl initdb psql createdb dropdb createuser dropuser'
for bin in $required_bins; do
  if [ ! -x "$prefix/bin/$bin" ]; then
    echo "missing executable: bin/$bin" >&2
    exit 1
  fi
done

mkdir -p "$prefix/lib" "$prefix/share" "$prefix/licenses/postgres" "$dist_dir"

archive="binaries-db-$tool-$version-$target.tar.xz"
tar -C "$prefix" -cf - . | xz -c > "$dist_dir/$archive"
if command -v sha256sum >/dev/null 2>&1; then
  (cd "$dist_dir" && sha256sum "$archive" > "$archive.sha256")
else
  (cd "$dist_dir" && shasum -a 256 "$archive" > "$archive.sha256")
fi

echo "$dist_dir/$archive"
