#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ci/utils.sh
. "$script_dir/../utils.sh"

usage() {
  cat >&2 <<EOF
usage:
  VERSION=<version> TARGET=<target> $0 build
  VERSION=<version> TARGET=<target> $0 package
  VERSION=<version> TARGET=<target> $0 verify
  VERSION=<version> TARGET=<target> $0 release
EOF
}

archive_path() {
  echo "$PWD/dist/$(archive_name mysql "$VERSION" "$TARGET")"
}

source_file() {
  case "$TARGET" in
    ubuntu24-amd64|ubuntu26-amd64|fedora43-amd64|fedora44-amd64) echo "mysql-${VERSION}-linux-glibc2.28-x86_64.tar.xz" ;;
    ubuntu24-arm64|ubuntu26-arm64|fedora43-arm64|fedora44-arm64) echo "mysql-${VERSION}-linux-glibc2.28-aarch64.tar.xz" ;;
    darwin-amd64) echo "mysql-${VERSION}-macos15-x86_64.tar.gz" ;;
    darwin-arm64) echo "mysql-${VERSION}-macos15-arm64.tar.gz" ;;
    *) echo "unsupported target: $TARGET" >&2; exit 1 ;;
  esac
}

version_line() {
  # MySQL download directories use the major.minor version line.
  echo "$VERSION" | cut -d. -f1,2
}

build_mysql() {
  read_env

  src="$PWD/src"
  source_url="https://cdn.mysql.com/Downloads/MySQL-$(version_line)/$(source_file)"

  rm -rf "$src" "$PREFIX"
  mkdir -p "$src" "$PREFIX"

  source_archive="$(download_archive "$source_url" "$src")"
  extract_archive "$source_archive" "$PREFIX" 1

  mkdir -p "$PREFIX/licenses/mysql"
  if [ -f "$PREFIX/LICENSE" ]; then
    cp "$PREFIX/LICENSE" "$PREFIX/licenses/mysql/LICENSE"
  fi
}

package_mysql() {
  read_env
  archive="$(archive_path)"

  required_bins='mysqld mysql mysqladmin mysqldump'
  for bin in $required_bins; do
    if [ ! -x "$PREFIX/bin/$bin" ]; then
      echo "missing executable: bin/$bin" >&2
      exit 1
    fi
  done

  archive_dir="$(dirname "$archive")"
  mkdir -p "$PREFIX/lib" "$PREFIX/share" "$PREFIX/licenses/mysql" "$archive_dir"

  archive_basename="$(basename "$archive")"
  tar -C "$PREFIX" -cf - . | xz -c > "$archive"
  (cd "$(dirname "$archive")" && sha256 "$archive_basename")

  echo "$archive"
}

verify_mysql() {
  read_env
  archive="$(archive_path)"

  if [ ! -f "$archive" ]; then
    echo "archive not found: $archive" >&2
    exit 1
  fi

  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT

  tar -xf "$archive" -C "$tmp_dir"

  required_bins='mysqld mysql mysqladmin mysqldump'
  for bin in $required_bins; do
    if [ ! -x "$tmp_dir/bin/$bin" ]; then
      echo "archive missing executable: bin/$bin" >&2
      exit 1
    fi
  done

  check_linked_libraries "$tmp_dir/bin/mysqld"
  check_linked_libraries "$tmp_dir/bin/mysql"
  check_linked_libraries "$tmp_dir/bin/mysqladmin"
  check_linked_libraries "$tmp_dir/bin/mysqldump"

  "$tmp_dir/bin/mysqld" --version
  "$tmp_dir/bin/mysql" --version
  "$tmp_dir/bin/mysqladmin" --version
  "$tmp_dir/bin/mysqldump" --version
}

release_mysql() {
  read_env
  archive="$(archive_path)"

  if [ ! -f "$archive" ]; then
    echo "archive not found: $archive" >&2
    exit 1
  fi

  if [ ! -f "$archive.sha256" ]; then
    echo "checksum not found: $archive.sha256" >&2
    exit 1
  fi

  release_upload mysql "$VERSION" "$archive"
}

if [ "$#" -lt 1 ]; then
  usage
  exit 2
fi

command="$1"
shift
if [ "$#" -ne 0 ]; then
  usage
  exit 2
fi

case "$command" in
  build) build_mysql ;;
  package) package_mysql ;;
  verify) verify_mysql ;;
  release) release_mysql ;;
  *) usage; exit 2 ;;
esac
