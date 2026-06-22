#!/usr/bin/env bash
# lib/detect.sh — detecção de SO, distro, arquitetura e gerenciador de pacotes.
# Requer que lib/common.sh já tenha sido carregado (usa command_exists).

if [ -n "${ENCHA_DETECT_SOURCED:-}" ]; then
  return 0 2>/dev/null || true
fi
ENCHA_DETECT_SOURCED=1

# ENCHA_OS = macos | linux | wsl | windows | unknown
detect_os() {
  local s; s="$(uname -s 2>/dev/null || echo unknown)"
  case "$s" in
    Darwin) ENCHA_OS="macos" ;;
    Linux)
      if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null || [ -n "${WSL_DISTRO_NAME:-}" ]; then
        ENCHA_OS="wsl"
      else
        ENCHA_OS="linux"
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*) ENCHA_OS="windows" ;;
    *) ENCHA_OS="unknown" ;;
  esac
  export ENCHA_OS
}

# ENCHA_ARCH = arm64 | x86_64 | <raw>
detect_arch() {
  local m; m="$(uname -m 2>/dev/null || echo unknown)"
  case "$m" in
    arm64|aarch64) ENCHA_ARCH="arm64" ;;
    x86_64|amd64)  ENCHA_ARCH="x86_64" ;;
    *) ENCHA_ARCH="$m" ;;
  esac
  export ENCHA_ARCH
}

# ENCHA_DISTRO_ID / ENCHA_DISTRO_FAMILY (debian | rhel | arch | unknown)
detect_distro() {
  ENCHA_DISTRO_ID="unknown"
  ENCHA_DISTRO_FAMILY="unknown"
  if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    ENCHA_DISTRO_ID="${ID:-unknown}"
    local like=" ${ID_LIKE:-} ${ID:-} "
    case "$like" in
      *debian*|*ubuntu*) ENCHA_DISTRO_FAMILY="debian" ;;
      *rhel*|*fedora*|*centos*) ENCHA_DISTRO_FAMILY="rhel" ;;
      *arch*) ENCHA_DISTRO_FAMILY="arch" ;;
      *) ENCHA_DISTRO_FAMILY="unknown" ;;
    esac
  fi
  export ENCHA_DISTRO_ID ENCHA_DISTRO_FAMILY
}

# ENCHA_NATIVE_PKG = apt | dnf | pacman | brew | none
detect_native_pkg() {
  if command_exists apt-get;  then ENCHA_NATIVE_PKG="apt"
  elif command_exists dnf;    then ENCHA_NATIVE_PKG="dnf"
  elif command_exists pacman; then ENCHA_NATIVE_PKG="pacman"
  elif command_exists brew;   then ENCHA_NATIVE_PKG="brew"
  else ENCHA_NATIVE_PKG="none"
  fi
  export ENCHA_NATIVE_PKG
}

detect_all() {
  detect_os
  detect_arch
  detect_distro
  detect_native_pkg
}

os_label() {
  case "${ENCHA_OS:-unknown}" in
    macos) printf 'macOS (%s)\n' "${ENCHA_ARCH:-?}" ;;
    linux) printf 'Linux %s (%s)\n' "${ENCHA_DISTRO_ID:-?}" "${ENCHA_ARCH:-?}" ;;
    wsl)   printf 'Windows/WSL2 %s (%s)\n' "${ENCHA_DISTRO_ID:-?}" "${ENCHA_ARCH:-?}" ;;
    *)     printf '%s (%s)\n' "${ENCHA_OS:-?}" "${ENCHA_ARCH:-?}" ;;
  esac
}
