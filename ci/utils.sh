#!/usr/bin/env bash

# Prints the release archive filename for tool, version, and target args.
archive_name() {
  tool="$1"
  version="$2"
  target="$3"

  echo "db-$tool-$version-$target.tar.xz"
}

# Prints the available CPU count.
cpu_count() {
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

# Downloads the url arg into the destination directory arg and prints the archive path.
download_archive() {
  url="$1"
  dest_dir="$2"
  archive="$dest_dir/$(basename "$url")"

  mkdir -p "$dest_dir"
  curl -fSL "$url" -o "$archive"
  echo "$archive"
}

# Extracts the archive arg into the destination directory arg with optional strip-components arg.
extract_archive() {
  archive="$1"
  dest_dir="$2"
  strip_components="${3:-0}"

  mkdir -p "$dest_dir"
  case "$archive" in
    *.tar|*.tar.gz|*.tgz|*.tar.bz2|*.tbz2|*.tar.xz|*.txz)
      tar -xf "$archive" -C "$dest_dir" --strip-components="$strip_components"
      ;;
    *.zip)
      if [ "$strip_components" -ne 0 ]; then
        echo "strip-components is not supported for zip archives" >&2
        exit 1
      fi
      unzip -q "$archive" -d "$dest_dir"
      ;;
    *)
      echo "unsupported archive type: $archive" >&2
      exit 1
      ;;
  esac
}

# Reads VERSION and TARGET env vars and sets the fixed PREFIX path.
read_env() {
  VERSION="${VERSION:-}"
  TARGET="${TARGET:-}"
  PREFIX="$PWD/prefix"

  if [ -z "$VERSION" ]; then
    echo "VERSION is required" >&2
    exit 2
  fi

  if [ -z "$TARGET" ]; then
    echo "TARGET is required" >&2
    exit 2
  fi

  validate_target "$TARGET"
}

# Creates or updates the GitHub release asset for tool, version, and archive args.
release_upload() {
  tool="$1"
  version="$2"
  archive="$3"

  tag="$tool-$version"
  if gh release view "$tag" >/dev/null 2>&1; then
    gh release upload "$tag" "$archive" "$archive.sha256" --clobber
  else
    gh release create "$tag" "$archive" "$archive.sha256" \
      --title "$tag" \
      --notes "Prebuilt $tool $version binaries."
  fi
}

# Writes a .sha256 checksum file for the archive arg.
sha256() {
  archive="$1"

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$archive" > "$archive.sha256"
  else
    shasum -a 256 "$archive" > "$archive.sha256"
  fi
}

# Validates the target arg against supported release targets.
validate_target() {
  target="$1"

  case "$target" in
    linux-amd64|linux-arm64|darwin-amd64|darwin-arm64) ;;
    *) echo "unsupported target: $target" >&2; exit 1 ;;
  esac
}
