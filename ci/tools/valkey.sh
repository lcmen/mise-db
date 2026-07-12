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
  echo "$PWD/dist/$(archive_name valkey "$VERSION" "$TARGET")"
}

configure_env() {
  case "$TARGET" in
    darwin-*)
      if ! command -v brew >/dev/null 2>&1; then
        echo "Homebrew is required for Darwin builds" >&2
        exit 1
      fi

      openssl_prefix="$(brew --prefix openssl@3)"
      export CPPFLAGS="${CPPFLAGS:-} -I$openssl_prefix/include"
      export LDFLAGS="${LDFLAGS:-} -L$openssl_prefix/lib"
      export PKG_CONFIG_PATH="$openssl_prefix/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
      ;;
  esac
}

build_valkey() {
  read_env

  src="$PWD/src"
  source_url="https://github.com/valkey-io/valkey/archive/refs/tags/${VERSION}.tar.gz"

  rm -rf "$src" "$PREFIX"
  mkdir -p "$src" "$PREFIX"

  source_archive="$(download_archive "$source_url" "$src")"
  extract_archive "$source_archive" "$src" 1

  cd "$src"
  configure_env
  make -j"$(cpu_count)" BUILD_TLS=yes
  make PREFIX="$PREFIX" BUILD_TLS=yes install

  mkdir -p "$PREFIX/licenses/valkey"
  cp COPYING "$PREFIX/licenses/valkey/COPYING"
}

package_valkey() {
  read_env
  archive="$(archive_path)"

  required_bins='valkey-server valkey-cli redis-server redis-cli'
  for bin in $required_bins; do
    if [ ! -x "$PREFIX/bin/$bin" ]; then
      echo "missing executable: bin/$bin" >&2
      exit 1
    fi
  done

  archive_dir="$(dirname "$archive")"
  mkdir -p "$PREFIX/lib" "$PREFIX/share" "$PREFIX/licenses/valkey" "$archive_dir"

  archive_basename="$(basename "$archive")"
  tar -C "$PREFIX" -cf - . | xz -c > "$archive"
  (cd "$(dirname "$archive")" && sha256 "$archive_basename")

  echo "$archive"
}

verify_valkey() {
  read_env
  archive="$(archive_path)"

  if [ ! -f "$archive" ]; then
    echo "archive not found: $archive" >&2
    exit 1
  fi

  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT

  tar -xf "$archive" -C "$tmp_dir"

  required_bins='valkey-server valkey-cli redis-server redis-cli'
  for bin in $required_bins; do
    if [ ! -x "$tmp_dir/bin/$bin" ]; then
      echo "archive missing executable: bin/$bin" >&2
      exit 1
    fi
  done

  check_linked_libraries "$tmp_dir/bin/valkey-server"
  check_linked_libraries "$tmp_dir/bin/valkey-cli"
  check_linked_libraries "$tmp_dir/bin/redis-server"
  check_linked_libraries "$tmp_dir/bin/redis-cli"

  "$tmp_dir/bin/valkey-server" --version
  "$tmp_dir/bin/valkey-cli" --version
  "$tmp_dir/bin/redis-server" --version
  "$tmp_dir/bin/redis-cli" --version
}

release_valkey() {
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

  release_upload valkey "$VERSION" "$archive"
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
  build) build_valkey ;;
  package) package_valkey ;;
  verify) verify_valkey ;;
  release) release_valkey ;;
  *) usage; exit 2 ;;
esac
