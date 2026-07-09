#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "usage: $0 setup" >&2
}

setup() {
  brew update && brew upgrade
  brew install \
    bison \
    flex \
    icu4c \
    libxml2 \
    libxslt \
    openssl@3 \
    pkg-config \
    readline \
    xz
}

if [ "$#" -ne 1 ]; then
  usage
  exit 2
fi

case "$1" in
  setup) setup ;;
  *) usage; exit 2 ;;
esac
