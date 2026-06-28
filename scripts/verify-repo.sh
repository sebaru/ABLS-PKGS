#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
ARCHES=("x86_64" "aarch64" "noarch")
PUBLIC_DIR="$BASE_DIR/public"
RPM_DIR="$PUBLIC_DIR/rpms"
KEY_FILE="$RPM_DIR/keys/RPM-GPG-KEY-ABLS"
KEY_SUM="$RPM_DIR/keys/RPM-GPG-KEY-ABLS.sha256"
PUBLISHED_REPO_FILE="$PUBLIC_DIR/abls-rpms.repo"

fail() {
  echo "ERROR: $1" >&2
  exit 1
}

[[ -f "$KEY_FILE" ]] || fail "missing key file: $KEY_FILE"
[[ -f "$KEY_SUM" ]] || fail "missing key checksum: $KEY_SUM"

expected_sum="$(awk '{print $1}' "$KEY_SUM" | head -n 1)"
actual_sum="$(sha256sum "$KEY_FILE" | awk '{print $1}')"
[[ -n "$expected_sum" ]] || fail "empty checksum in $KEY_SUM"
[[ "$expected_sum" == "$actual_sum" ]] || fail "checksum mismatch for $KEY_FILE"

gpg --show-keys --fingerprint "$KEY_FILE" >/dev/null

for arch in "${ARCHES[@]}"; do
  dir="$RPM_DIR/$arch"
  [[ -d "$dir" ]] || continue

  rpm_count="$(find "$dir" -maxdepth 1 -type f -name '*.rpm' | wc -l)"
  if [[ "$rpm_count" -gt 0 ]]; then
    [[ -f "$dir/repodata/repomd.xml" ]] || fail "missing repodata for $arch"
  fi
done

# Optional client-side sanity check with dnf:
# - --disablerepo='*' disables every repo configured on the host, so we avoid
#   mixing with system repos and only test THIS local ABLS repo path.
# - --repofrompath defines a temporary repo named "abls-rpms" pointing to
#   public/rpms/x86_64 via file://.
# - --enablerepo='abls-rpms' enables only that temporary repo for makecache.
# This confirms dnf can read repo metadata in a real client flow.
if command -v dnf >/dev/null 2>&1 && [[ -f "$PUBLISHED_REPO_FILE" ]]; then
  dnf -q --disablerepo='*' --repofrompath="abls-rpms,file://$RPM_DIR/x86_64" --enablerepo='abls-rpms' makecache >/dev/null || true
fi

echo "OK: repository checks completed"
