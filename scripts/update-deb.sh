#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
PUBLIC_DIR="$BASE_DIR/public"
DEB_BASE="$PUBLIC_DIR/deb"
DROP_DIR="$BASE_DIR/deb-packages"
CONF_DIR="$DEB_BASE/conf"
DIST_FILE="$CONF_DIR/distributions"
CLEAN_MODE=0
SUITES=("bookworm" "trixie")
ARCHES="amd64 arm64 armhf"
GPG_KEY_ID="6C86F2C11305554A61A2221512671FDB87025D1B"

if [[ "${1:-}" == "clean" || "${1:-}" == "--clean" ]]; then
  CLEAN_MODE=1
elif [[ -n "${1:-}" ]]; then
  echo "ERROR: unknown argument: $1" >&2
  echo "Usage: $0 [clean|--clean]" >&2
  exit 1
fi

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: missing command: $cmd" >&2
    if [[ "$cmd" == "reprepro" ]]; then
      echo "Install hint: sudo apt install -y reprepro" >&2
    fi
    exit 1
  fi
}

require_cmd reprepro

mkdir -p "$PUBLIC_DIR" "$DEB_BASE" "$DROP_DIR" "$CONF_DIR"

if [[ ! -f "$DIST_FILE" ]]; then
  cat > "$DIST_FILE" <<EOF
Origin: ABLS
Label: ABLS Debian Repository
Suite: bookworm
Codename: bookworm
Architectures: $ARCHES
Components: main
Description: ABLS Debian packages (bookworm)
SignWith: $GPG_KEY_ID

Origin: ABLS
Label: ABLS Debian Repository
Suite: trixie
Codename: trixie
Architectures: $ARCHES
Components: main
Description: ABLS Debian packages (trixie)
SignWith: $GPG_KEY_ID
EOF
fi

for suite in "${SUITES[@]}"; do
  mkdir -p "$DROP_DIR/$suite"
done

if [[ "$CLEAN_MODE" -eq 1 ]]; then
  rm -rf "$DEB_BASE/db" "$DEB_BASE/dists" "$DEB_BASE/pool"
fi

published=0
for suite in "${SUITES[@]}"; do
  shopt -s nullglob
  debs=("$DROP_DIR/$suite"/*.deb)
  shopt -u nullglob

  if [[ ${#debs[@]} -eq 0 ]]; then
    continue
  fi

  for deb in "${debs[@]}"; do
    reprepro -b "$DEB_BASE" includedeb "$suite" "$deb"
    published=1
  done
done

if [[ "$published" -eq 0 ]]; then
  echo "WARN: no .deb files found in $DROP_DIR/<suite>/"
else
  echo "OK: deb repository updated in $DEB_BASE"
fi
