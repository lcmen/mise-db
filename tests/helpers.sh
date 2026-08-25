#!/usr/bin/env bash
# shellcheck shell=bash

ROOT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT=""

setup_mise() {
  TEST_ROOT="$(mktemp -d "/tmp/mise-db-test.XXXXXX")"
  export MISE_CACHE_DIR="$TEST_ROOT/cache"
  export MISE_CONFIG_DIR="$TEST_ROOT/config"
  export MISE_DATA_DIR="$TEST_ROOT/data"
  export MISE_STATE_DIR="$TEST_ROOT/state"

  run_mise plugin link db "$ROOT_DIR"
}

run_mise() {
  mise -C "$TEST_ROOT" "$@"
}

cleanup_mise() {
  if [[ -n "${TEST_ROOT:-}" && "$TEST_ROOT" == /tmp/mise-db-test.* ]]; then
    rm -rf "$TEST_ROOT"
  fi
}

tool_version() {
  local tool="${1:?tool is required}"

  awk -v tool="$tool" '
    $0 ~ "\"tool\": \"" tool "\"" {
      getline
      gsub(/[\",]/, "", $2)
      print $2
      exit
    }
  ' "$ROOT_DIR/ci/tools.json"
}

current_target() {
  local architecture

  case "$(uname -m)" in
    arm64|aarch64) architecture="arm64" ;;
    x86_64|amd64) architecture="amd64" ;;
    *) echo "unsupported test architecture: $(uname -m)" >&2; return 1 ;;
  esac

  case "$(uname -s)" in
    Darwin)
      echo "darwin-$architecture"
      ;;
    Linux)
      local distro_id version_id
      distro_id="$(awk -F= '$1 == "ID" { gsub(/"/, "", $2); print $2 }' /etc/os-release)"
      version_id="$(awk -F= '$1 == "VERSION_ID" { gsub(/"/, "", $2); split($2, parts, "."); print parts[1] }' /etc/os-release)"
      echo "$distro_id$version_id-$architecture"
      ;;
    *)
      echo "unsupported test operating system: $(uname -s)" >&2
      return 1
      ;;
  esac
}

prepare_release() {
  local tool="${1:?tool is required}"
  local version="${2:?version is required}"
  shift 2
  local archive asset_dir fixture_dir target

  target="$(current_target)"
  asset_dir="$TEST_ROOT/assets"
  archive="$asset_dir/$tool-$version-$target.tar.xz"
  fixture_dir="$TEST_ROOT/fixture"
  mkdir -p "$asset_dir" "$fixture_dir/bin" "$fixture_dir/lib" "$fixture_dir/share" "$fixture_dir/licenses/$tool"

  local command_name
  for command_name in "$@"; do
    printf '#!/usr/bin/env bash\nprintf "%%s\\n" "%s %s"\n' "$tool" "$version" >"$fixture_dir/bin/$command_name"
    chmod 755 "$fixture_dir/bin/$command_name"
  done

  tar -cJf "$archive" -C "$fixture_dir" .
  printf '[tools]\n"db:%s" = "%s"\n' "$tool" "$version" >"$TEST_ROOT/mise.toml"
  export MISE_DB_ASSET_DIR="$asset_dir"
}

assert_include() {
  local expected="${1:?expected text is required}"
  local actual="${2-}"

  if [[ "$actual" != *"$expected"* ]]; then
    echo "expected text to include: $expected" >&2
    echo "actual text: $actual" >&2
    return 1
  fi
}

assert_line() {
  local expected="${1:?expected line is required}"

  if ! sed 's/\r$//' | grep -Fx "$expected" >/dev/null; then
    echo "expected output to include: $expected" >&2
    return 1
  fi
}

install_tool() {
  local tool="${1:?tool is required}"
  local version="${2:?version is required}"

  run_mise install "db:$tool@$version"
}

run_tool() {
  local tool="${1:?tool is required}"
  local version="${2:?version is required}"
  shift 2

  run_mise exec "db:$tool@$version" -- "$@"
}
