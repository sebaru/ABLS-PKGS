#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/home/sebastien/ABLS-RPMS"

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: missing command: $cmd" >&2
    exit 1
  fi
}

require_cmd gpg
require_cmd rpm

if ! command -v createrepo_c >/dev/null 2>&1 && ! command -v createrepo >/dev/null 2>&1; then
  echo "ERROR: missing command: createrepo_c or createrepo" >&2
  exit 1
fi

mkdir -p \
  "$BASE_DIR/repo/x86_64" \
  "$BASE_DIR/repo/aarch64" \
  "$BASE_DIR/repo/noarch" \
  "$BASE_DIR/keys" \
  "$BASE_DIR/scripts" \
  "$BASE_DIR/published"

echo "OK: ABLS-RPMS structure initialized in $BASE_DIR"
