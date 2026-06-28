#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/scripts"
CLEAN_MODE=0

if [[ "${1:-}" == "clean" || "${1:-}" == "--clean" ]]; then
	CLEAN_MODE=1
elif [[ -n "${1:-}" ]]; then
	echo "ERROR: unknown argument: $1" >&2
	echo "Usage: $0 [clean|--clean]" >&2
	exit 1
fi

if [[ "$CLEAN_MODE" -eq 1 ]]; then
	"$SCRIPT_DIR/update-rpm.sh" --clean
	"$SCRIPT_DIR/update-deb.sh" --clean
else
	"$SCRIPT_DIR/update-rpm.sh"
	"$SCRIPT_DIR/update-deb.sh"
fi
"$SCRIPT_DIR/verify-repo.sh"
git add public/

if [[ "$CLEAN_MODE" -eq 1 ]]; then
	echo "OK: update completed (clean + publish rpm/deb + verify rpm)"
else
	echo "OK: update completed (publish rpm/deb + verify rpm)"
fi
