#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 <version> <target> <prefix>" >&2
}

if [ "$#" -ne 3 ]; then
  usage
  exit 2
fi

version="$1"
target="$2"
prefix="$3"

case "$target" in
  linux-amd64-gnu|linux-arm64-gnu|darwin-amd64|darwin-arm64) ;;
  *) echo "unsupported target: $target" >&2; exit 1 ;;
esac

jobs() {
  job_count=""
  if command -v nproc >/dev/null 2>&1; then
    job_count="$(nproc)"
  elif command -v sysctl >/dev/null 2>&1; then
    job_count="$(sysctl -n hw.ncpu 2>/dev/null || true)"
  fi

  if [ -z "$job_count" ]; then
    job_count="$(getconf _NPROCESSORS_ONLN 2>/dev/null || true)"
  fi

  if [ -z "$job_count" ]; then
    job_count=2
  fi

  echo "$job_count"
}

configure_env() {
  case "$target" in
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

work_dir="${WORK_DIR:-$PWD/work/postgres-$version-$target}"
source_url="https://ftp.postgresql.org/pub/source/v${version}/postgresql-${version}.tar.bz2"
archive="$work_dir/postgresql-${version}.tar.bz2"
src_dir="$work_dir/postgresql-${version}"

rm -rf "$work_dir" "$prefix"
mkdir -p "$work_dir" "$prefix"

curl -fSL "$source_url" -o "$archive"
tar -xf "$archive" -C "$work_dir"

cd "$src_dir"
configure_env
./configure \
  --prefix="$prefix" \
  --with-openssl \
  --with-icu \
  --with-libxml \
  --with-libxslt
make -j"$(jobs)"
make install

mkdir -p "$prefix/licenses/postgres"
cp COPYRIGHT "$prefix/licenses/postgres/COPYRIGHT"
