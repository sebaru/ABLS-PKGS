#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
PUBLIC_DIR="$BASE_DIR/public"
DEB_BASE="$PUBLIC_DIR/deb"
DROP_DIR="$BASE_DIR/deb-packages"
CONF_DIR="$DEB_BASE/conf"
DIST_FILE="$CONF_DIR/distributions"
SUITES=("bookworm" "trixie")
ARCHES="amd64 arm64 armhf"

if [[ -n "${1:-}" ]]; then
  echo "ERROR: unknown argument: $1" >&2
  echo "Usage: $0" >&2
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

Origin: ABLS
Label: ABLS Debian Repository
Suite: trixie
Codename: trixie
Architectures: $ARCHES
Components: main
Description: ABLS Debian packages (trixie)
EOF
fi

# Import hosts may not have the private key; strip SignWith lines before export.
tmp_dist="$(mktemp)"
awk '!/^SignWith:[[:space:]]+/' "$DIST_FILE" > "$tmp_dist"
if ! cmp -s "$DIST_FILE" "$tmp_dist"; then
  mv "$tmp_dist" "$DIST_FILE"
  echo "WARN: normalized $DIST_FILE to remove SignWith entries for import-only mode" >&2
else
  rm -f "$tmp_dist"
fi

for suite in "${SUITES[@]}"; do
  mkdir -p "$DROP_DIR/$suite"
done

published=0
for suite in "${SUITES[@]}"; do
  shopt -s nullglob
  debs=("$DROP_DIR/$suite"/*.deb "$DROP_DIR/$suite"/*/*.deb)
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
fi

# Export indexes after import; metadata may be unsigned in import-only mode.
reprepro -b "$DEB_BASE" export

git add public/deb/

echo "OK: deb repository imported in $DEB_BASE (unsigned metadata export)"
