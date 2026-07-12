#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ci/utils.sh
. "$script_dir/../utils.sh"

usage() {
  echo "usage: $0 setup|runtime" >&2
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

runtime_apt() {
  apt update

  apt install -y --no-install-recommends \
    ca-certificates \
    libaio1t64 \
    libnuma1 \
    libreadline8t64 \
    libxslt1.1 \
    openssl \
    xz-utils \
    zlib1g

  if apt-cache show libxml2 >/dev/null 2>&1; then
    apt install -y --no-install-recommends libxml2
  else
    apt install -y --no-install-recommends libxml2-16
  fi
}

runtime_dnf() {
  dnf install -y \
    ca-certificates \
    libaio \
    libicu \
    libxml2 \
    libxslt \
    numactl-libs \
    openssl-libs \
    readline \
    tar \
    xz \
    zlib
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

runtime() {
  if command -v apt >/dev/null 2>&1; then
    runtime_apt
  elif command -v dnf >/dev/null 2>&1; then
    runtime_dnf
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
  runtime) runtime ;;
  *) usage; exit 2 ;;
esac
