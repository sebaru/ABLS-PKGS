#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
PUBLIC_DIR="$BASE_DIR/public"
RPM_DIR="$PUBLIC_DIR/rpms"
ARCHES=("x86_64" "aarch64" "noarch")

if [[ -n "${1:-}" ]]; then
  echo "ERROR: unknown argument: $1" >&2
  echo "Usage: $0" >&2
  exit 1
fi

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: missing command: $cmd" >&2
    exit 1
  fi
}

require_cmd gpg
require_cmd rpmsign
require_cmd rpm

if command -v createrepo_c >/dev/null 2>&1; then
  CREATEREPO_CMD="createrepo_c"
elif command -v createrepo >/dev/null 2>&1; then
  CREATEREPO_CMD="createrepo"
else
  echo "ERROR: missing command: createrepo_c or createrepo" >&2
  exit 1
fi

GPG_KEY_ID="6C86F2C11305554A61A2221512671FDB87025D1B"

if ! gpg --batch --list-secret-keys "$GPG_KEY_ID" >/dev/null 2>&1; then
  echo "ERROR: missing GPG secret key for RPM signing: $GPG_KEY_ID" >&2
  echo "Import the private key on this publisher host before running update-rpm.sh" >&2
  exit 1
fi

sign_rpm_if_needed() {
  local rpm_file="$1"
  local checksig_output

  checksig_output="$(rpm --checksig "$rpm_file" 2>&1 || true)"
  if grep -Eqi 'signatures?[^[:alpha:]]+OK|pgp[^[:alpha:]]+OK|rsa[^[:alpha:]]+OK|ecdsa[^[:alpha:]]+OK|eddsa[^[:alpha:]]+OK' <<<"$checksig_output"; then
    return 0
  fi

  rpmsign --key-id "$GPG_KEY_ID" --addsign "$rpm_file" >/dev/null

  checksig_output="$(rpm --checksig "$rpm_file" 2>&1 || true)"
  if ! grep -Eqi 'signatures?[^[:alpha:]]+OK|pgp[^[:alpha:]]+OK|rsa[^[:alpha:]]+OK|ecdsa[^[:alpha:]]+OK|eddsa[^[:alpha:]]+OK' <<<"$checksig_output"; then
    echo "ERROR: unsigned or invalid signature for $rpm_file" >&2
    echo "rpm --checksig output: $checksig_output" >&2
    exit 1
  fi
}

mkdir -p "$RPM_DIR" "$RPM_DIR/keys"

for arch in "${ARCHES[@]}"; do
  dst="$RPM_DIR/$arch"
  mkdir -p "$dst"

  shopt -s nullglob
  rpms=("$dst"/*.rpm)
  shopt -u nullglob

  for rpm_file in "${rpms[@]}"; do
    sign_rpm_if_needed "$rpm_file"
  done

  # Keep metadata aligned with what is effectively exposed.
  "$CREATEREPO_CMD" --update "$dst" >/dev/null

  repomd="$dst/repodata/repomd.xml"
  if [[ -f "$repomd" && -n "${GPG_KEY_ID:-}" ]]; then
    gpg --batch --yes --detach-sign --armor --local-user "$GPG_KEY_ID" \
      --output "$repomd.asc" "$repomd"
  fi
done

if [[ ! -f "$RPM_DIR/keys/RPM-GPG-KEY-ABLS" ]]; then
  gpg --batch --yes --armor --export "$GPG_KEY_ID" > "$RPM_DIR/keys/RPM-GPG-KEY-ABLS"
fi

if [[ ! -f "$RPM_DIR/keys/RPM-GPG-KEY-ABLS" ]]; then
  echo "ERROR: missing public key export for RPM signing: $RPM_DIR/keys/RPM-GPG-KEY-ABLS" >&2
  exit 1
fi

if [[ -f "$RPM_DIR/keys/RPM-GPG-KEY-ABLS" ]]; then
  sha256sum "$RPM_DIR/keys/RPM-GPG-KEY-ABLS" | awk '{print $1 "  keys/RPM-GPG-KEY-ABLS"}' > "$RPM_DIR/keys/RPM-GPG-KEY-ABLS.sha256"

  # Publish APT keyring artifacts derived from the same ABLS public key.
  cp -f "$RPM_DIR/keys/RPM-GPG-KEY-ABLS" "$PUBLIC_DIR/abls-archive-keyring.asc"
  gpg --dearmor --yes --output "$PUBLIC_DIR/abls-archive-keyring.gpg" "$RPM_DIR/keys/RPM-GPG-KEY-ABLS"
fi

git add \
	public/rpms/ \
	public/abls-archive-keyring.asc \
	public/abls-archive-keyring.gpg

echo "OK: repository updated in-place in public/rpms/"

"$SCRIPT_DIR/verify-repo.sh"
echo "OK: RPM update completed"
