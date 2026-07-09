#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "usage: $0 setup" >&2
}

setup() {
  sudo apt-get update
  sudo apt-get install -y --no-install-recommends \
    bison \
    build-essential \
    ca-certificates \
    curl \
    flex \
    libicu-dev \
    libreadline-dev \
    libssl-dev \
    libxml2-dev \
    libxslt1-dev \
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
