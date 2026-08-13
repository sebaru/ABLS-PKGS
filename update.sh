#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/scripts"

if [[ -n "${1:-}" ]]; then
	echo "ERROR: unknown argument: $1" >&2
	echo "Usage: $0" >&2
	exit 1
fi

detect_host_family() {
	if [[ -r /etc/os-release ]]; then
		# shellcheck disable=SC1091
		. /etc/os-release
		local os_tags="${ID:-} ${ID_LIKE:-}"
		if [[ "$os_tags" =~ (fedora|rhel|centos|rocky|alma|suse) ]]; then
			echo rpm
			return 0
		fi
		if [[ "$os_tags" =~ (debian|ubuntu|raspbian|linuxmint) ]]; then
			echo deb
			return 0
		fi
	fi

	if command -v dnf >/dev/null 2>&1 || command -v rpm >/dev/null 2>&1; then
		echo rpm
		return 0
	fi

	if command -v apt-get >/dev/null 2>&1 || command -v dpkg >/dev/null 2>&1; then
		echo deb
		return 0
	fi

	echo "ERROR: unsupported host family; expected RPM or Debian host" >&2
	return 1
}

host_family="$(detect_host_family)"

case "$host_family" in
	rpm)
		"$SCRIPT_DIR/update-rpm.sh"
		git add public/rpms/ public/abls-archive-keyring.asc public/abls-archive-keyring.gpg
		echo "OK: RPM repository updated on RPM host"
		;;
	deb)
		"$SCRIPT_DIR/update-deb.sh"
		git add public/deb/ public/abls-archive-keyring.asc public/abls-archive-keyring.gpg
		echo "OK: DEB repository updated on Debian host"
		;;
esac

"$SCRIPT_DIR/verify-repo.sh"
echo "OK: update completed ($host_family host + repository verification)"
