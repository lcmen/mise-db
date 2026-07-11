#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "usage: $0 setup" >&2
}

setup() {
  sudo apt update
  sudo apt install -y --no-install-recommends \
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

if [ "$#" -ne 1 ]; then
  usage
  exit 2
fi

case "$1" in
  setup) setup ;;
  *) usage; exit 2 ;;
esac
