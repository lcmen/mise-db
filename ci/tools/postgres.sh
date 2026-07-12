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
  echo "$PWD/dist/$(archive_name postgres "$VERSION" "$TARGET")"
}

configure_env() {
  case "$TARGET" in
    darwin-*)
      if ! command -v brew >/dev/null 2>&1; then
        echo "Homebrew is required for Darwin builds" >&2
        exit 1
      fi

      export CPPFLAGS="${CPPFLAGS:-}"
      export LDFLAGS="${LDFLAGS:-}"
      export PKG_CONFIG_PATH="${PKG_CONFIG_PATH:-}"

      for formula in openssl@3 icu4c libxml2 libxslt readline; do
        formula_prefix="$(brew --prefix "$formula")"
        CPPFLAGS="$CPPFLAGS -I$formula_prefix/include"
        LDFLAGS="$LDFLAGS -L$formula_prefix/lib"
        PKG_CONFIG_PATH="$formula_prefix/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
      done

      export CPPFLAGS LDFLAGS PKG_CONFIG_PATH
      export PATH="$(brew --prefix bison)/bin:$(brew --prefix flex)/bin:$(brew --prefix libxml2)/bin:$(brew --prefix libxslt)/bin:$PATH"
      ;;
  esac
}

build_postgres() {
  read_env

  src="$PWD/src"
  source_url="https://ftp.postgresql.org/pub/source/v${VERSION}/postgresql-${VERSION}.tar.bz2"

  rm -rf "$src" "$PREFIX"
  mkdir -p "$src" "$PREFIX"

  source_archive="$(download_archive "$source_url" "$src")"
  extract_archive "$source_archive" "$src" 1

  cd "$src"
  configure_env
  ./configure \
    --prefix="$PREFIX" \
    --with-openssl \
    --with-icu \
    --with-libxml \
    --with-libxslt
  make -j"$(cpu_count)"
  make install

  mkdir -p "$PREFIX/licenses/postgres"
  cp COPYRIGHT "$PREFIX/licenses/postgres/COPYRIGHT"
}

package_postgres() {
  read_env
  archive="$(archive_path)"

  required_bins='postgres pg_ctl initdb psql createdb dropdb createuser dropuser'
  for bin in $required_bins; do
    if [ ! -x "$PREFIX/bin/$bin" ]; then
      echo "missing executable: bin/$bin" >&2
      exit 1
    fi
  done

  archive_dir="$(dirname "$archive")"
  mkdir -p "$PREFIX/lib" "$PREFIX/share" "$PREFIX/licenses/postgres" "$archive_dir"

  archive_basename="$(basename "$archive")"
  tar -C "$PREFIX" -cf - . | xz -c > "$archive"
  (cd "$(dirname "$archive")" && sha256 "$archive_basename")

  echo "$archive"
}

verify_postgres() {
  read_env
  archive="$(archive_path)"

  if [ ! -f "$archive" ]; then
    echo "archive not found: $archive" >&2
    exit 1
  fi

  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT

  tar -xf "$archive" -C "$tmp_dir"

  required_bins='postgres pg_ctl initdb psql createdb dropdb createuser dropuser'
  for bin in $required_bins; do
    if [ ! -x "$tmp_dir/bin/$bin" ]; then
      echo "archive missing executable: bin/$bin" >&2
      exit 1
    fi
  done

  check_linked_libraries "$tmp_dir/bin/postgres"
  check_linked_libraries "$tmp_dir/bin/psql"
  check_linked_libraries "$tmp_dir/bin/initdb"

  "$tmp_dir/bin/postgres" --version
  "$tmp_dir/bin/psql" --version
  "$tmp_dir/bin/initdb" --version
}

release_postgres() {
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

  release_upload postgres "$VERSION" "$archive"
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
  build) build_postgres ;;
  package) package_postgres ;;
  verify) verify_postgres ;;
  release) release_postgres ;;
  *) usage; exit 2 ;;
esac
