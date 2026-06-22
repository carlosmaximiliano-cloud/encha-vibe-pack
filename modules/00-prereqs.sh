#!/usr/bin/env bash
# modules/00-prereqs.sh — pré-requisitos do sistema (compiladores, git, curl…).
# Idempotente. Roda antes do Homebrew.
set -euo pipefail
: "${ENCHA_LIB:?ENCHA_LIB não definido — rode via run.sh}"
# shellcheck source=../lib/common.sh
. "$ENCHA_LIB/common.sh"
# shellcheck source=../lib/detect.sh
. "$ENCHA_LIB/detect.sh"
# shellcheck source=../lib/pkg.sh
. "$ENCHA_LIB/pkg.sh"

case "${ENCHA_OS:-}" in
  macos)
    if xcode-select -p >/dev/null 2>&1; then
      log_success "Xcode Command Line Tools já instalados."
    else
      log_info "Instalando Xcode Command Line Tools (pode abrir uma janela do sistema)…"
      if ! is_dry_run; then
        xcode-select --install 2>/dev/null || true
        log_warn "Se uma janela abriu, conclua a instalação e rode o instalador novamente."
      fi
    fi
    ;;
  linux|wsl)
    native_update || log_warn "não foi possível atualizar índices do gerenciador (seguindo)."
    case "${ENCHA_NATIVE_PKG:-none}" in
      apt)
        native_install build-essential procps curl file git ca-certificates unzip wget
        ;;
      dnf)
        # 'Development Tools' como grupo; com fallback para pacotes avulsos.
        if ! sudo_run dnf group install -y "Development Tools" 2>/dev/null; then
          native_install gcc gcc-c++ make
        fi
        native_install procps-ng curl file git ca-certificates unzip wget
        ;;
      pacman)
        native_install base-devel procps-ng curl file git ca-certificates unzip wget
        ;;
      *)
        log_warn "Gerenciador de pacotes nativo não reconhecido; pulei os pré-requisitos de build."
        ;;
    esac
    ;;
  *)
    die "SO não suportado em prereqs: ${ENCHA_OS:-desconhecido}"
    ;;
esac

log_success "Pré-requisitos concluídos."
