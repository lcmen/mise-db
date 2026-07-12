#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ci/utils.sh
. "$script_dir/../utils.sh"

usage() {
  echo "usage: $0 setup" >&2
}

setup_apt() {
  apt update

  apt install -y --no-install-recommends \
    bison \
    build-essential \
    ca-certificates \
    curl \
    flex \
    libaio1t64 \
    libicu-dev \
    libnuma1 \
    libreadline-dev \
    libssl-dev \
    libxml2-dev \
    libxslt1-dev \
    pkg-config \
    xz-utils \
    zlib1g-dev
}

setup_dnf() {
  dnf install -y \
    bison \
    ca-certificates \
    curl \
    findutils \
    flex \
    gcc \
    gcc-c++ \
    glibc-langpack-en \
    libaio \
    libicu-devel \
    libxml2-devel \
    libxslt-devel \
    make \
    numactl-libs \
    openssl-devel \
    perl \
    pkgconf-pkg-config \
    readline-devel \
    tar \
    xz \
    zlib-devel
}

setup() {
  if command -v apt >/dev/null 2>&1; then
    setup_apt
  elif command -v dnf >/dev/null 2>&1; then
    setup_dnf
  else
    echo "unsupported Linux package manager; expected apt or dnf" >&2
    exit 1
  fi
}

if [ "$#" -ne 1 ]; then
  usage
  exit 2
fi

case "$1" in
  setup) setup ;;
  *) usage; exit 2 ;;
esac
