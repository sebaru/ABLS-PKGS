#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

if [[ -n "${1:-}" ]]; then
  echo "ERROR: unknown argument: $1" >&2
  echo "Usage: ./$SCRIPT_NAME" >&2
  exit 1
fi

if [[ "$EUID" -eq 0 ]]; then
  SUDO=()
elif command -v sudo >/dev/null 2>&1; then
  SUDO=(sudo)
else
  echo "ERROR: root or sudo is required to install packages" >&2
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

install_rpm_deps() {
  local packages=(
    createrepo_c
    git
    gnupg2
    rpm-sign
  )

  if command -v dnf >/dev/null 2>&1; then
    "${SUDO[@]}" dnf install -y "${packages[@]}"
    return 0
  fi

  echo "ERROR: dnf not found on RPM host" >&2
  return 1
}

install_deb_deps() {
  local packages=(
    git
    gnupg
    reprepro
  )

  if command -v apt-get >/dev/null 2>&1; then
    "${SUDO[@]}" apt-get update
    "${SUDO[@]}" apt-get install -y "${packages[@]}"
    return 0
  fi

  echo "ERROR: apt-get not found on Debian host" >&2
  return 1
}

host_family="$(detect_host_family)"

case "$host_family" in
  rpm)
    install_rpm_deps
    echo "OK: installed RPM host dependencies"
    ;;
  deb)
    install_deb_deps
    echo "OK: installed Debian host dependencies"
    ;;
esac