#!/usr/bin/env bash

set -euo pipefail

cwd=$(dirname "${BASH_SOURCE[0]}")

for test_file in "$cwd"/*.test.sh; do
  "$test_file"
done
