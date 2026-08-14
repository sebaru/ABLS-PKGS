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
GPG_KEY_ID="6C86F2C11305554A61A2221512671FDB87025D1B"

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
require_cmd gpg

if ! gpg --batch --list-secret-keys "$GPG_KEY_ID" >/dev/null 2>&1; then
  echo "ERROR: missing GPG secret key for SignWith: $GPG_KEY_ID" >&2
  echo "Import the private key on this publisher host before running update-deb.sh" >&2
  exit 1
fi

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

tmp_dist="$(mktemp)"
awk -v key="$GPG_KEY_ID" '
BEGIN {
  saw_sign = 0
}
{
  if ($0 ~ /^SignWith:[[:space:]]+/) {
    saw_sign = 1
  }

  if ($0 == "") {
    if (NR > 1 && saw_sign == 0) {
      print "SignWith: " key
    }
    print ""
    saw_sign = 0
    next
  }

  print
}
END {
  if (NR > 0 && saw_sign == 0) {
    print "SignWith: " key
  }
}
' "$DIST_FILE" > "$tmp_dist"

if ! cmp -s "$DIST_FILE" "$tmp_dist"; then
  mv "$tmp_dist" "$DIST_FILE"
  echo "WARN: normalized $DIST_FILE to add missing SignWith entries" >&2
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

# Always export to refresh dists metadata and signatures, even when packages are unchanged.
reprepro -b "$DEB_BASE" export

if [[ ! -f "$BASE_DIR/public/rpms/keys/RPM-GPG-KEY-ABLS" ]]; then
  gpg --batch --yes --armor --export "$GPG_KEY_ID" > "$BASE_DIR/public/rpms/keys/RPM-GPG-KEY-ABLS"
fi

if [[ ! -f "$BASE_DIR/public/rpms/keys/RPM-GPG-KEY-ABLS" ]]; then
  echo "ERROR: missing public key export for APT keyring generation: $BASE_DIR/public/rpms/keys/RPM-GPG-KEY-ABLS" >&2
  exit 1
fi

if [[ -f "$BASE_DIR/public/rpms/keys/RPM-GPG-KEY-ABLS" ]]; then
  cp -f "$BASE_DIR/public/rpms/keys/RPM-GPG-KEY-ABLS" "$PUBLIC_DIR/abls-archive-keyring.asc"
  gpg --dearmor --yes --output "$PUBLIC_DIR/abls-archive-keyring.gpg" "$BASE_DIR/public/rpms/keys/RPM-GPG-KEY-ABLS"
fi

echo "OK: deb repository updated in $DEB_BASE (signed metadata exported)"
