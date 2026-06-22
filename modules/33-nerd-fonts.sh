#!/usr/bin/env bash
# modules/33-nerd-fonts.sh — instala uma Nerd Font (FiraCode) para ícones do
# prompt/terminal funcionarem. No WSL a fonte deve ser instalada no Windows.
set -euo pipefail
: "${ENCHA_LIB:?ENCHA_LIB não definido — rode via run.sh}"
# shellcheck source=../lib/common.sh
. "$ENCHA_LIB/common.sh"
# shellcheck source=../lib/detect.sh
. "$ENCHA_LIB/detect.sh"
# shellcheck source=../lib/pkg.sh
. "$ENCHA_LIB/pkg.sh"
# shellcheck source=../lib/security.sh
. "$ENCHA_LIB/security.sh"

NERD_VERSION="v3.2.1"   # versão fixada (estabilidade)

case "${ENCHA_OS:-}" in
  macos)
    load_brew_env || true
    brew_install_cask font-fira-code-nerd-font || log_warn "não consegui instalar a fonte via cask."
    log_success "Nerd Font (FiraCode) instalada."
    log_info "Configure seu terminal para usar 'FiraCode Nerd Font'."
    ;;

  wsl)
    log_warn "No WSL, a fonte precisa ser instalada no WINDOWS (o terminal é do Windows)."
    log_info "Baixe e instale no Windows: https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_VERSION}/FiraCode.zip"
    log_info "Depois selecione 'FiraCode Nerd Font' nas configurações do Windows Terminal."
    ;;

  linux)
    if command_exists fc-list && fc-list 2>/dev/null | grep -qi "FiraCode Nerd"; then
      log_success "FiraCode Nerd Font já instalada."
      exit 0
    fi
    if is_dry_run; then
      log_info "[dry-run] baixaria FiraCode ${NERD_VERSION} para ~/.local/share/fonts e rodaria fc-cache."
      exit 0
    fi
    fonts_dir="$HOME/.local/share/fonts/FiraCodeNerdFont"
    mkdir -p "$fonts_dir"
    tmp="$(mktemp -d "${TMPDIR:-/tmp}/encha-font.XXXXXX")"
    # shellcheck disable=SC2064
    trap "rm -rf '$tmp'" EXIT
    url="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_VERSION}/FiraCode.zip"
    log_info "Baixando FiraCode Nerd Font ${NERD_VERSION}…"
    if ! download_verified "$url" "$tmp/FiraCode.zip"; then
      log_warn "falha ao baixar a fonte."
      exit 1
    fi
    unzip -oq "$tmp/FiraCode.zip" -d "$fonts_dir" || { log_warn "falha ao extrair a fonte."; exit 1; }
    if command_exists fc-cache; then
      fc-cache -f "$fonts_dir" >/dev/null 2>&1 || true
    else
      log_warn "fc-cache não encontrado; instale 'fontconfig' para atualizar o cache de fontes."
    fi
    log_success "FiraCode Nerd Font instalada em $fonts_dir."
    log_info "Configure seu terminal para usar 'FiraCode Nerd Font'."
    ;;

  *)
    log_warn "SO não suportado para instalação de fontes: ${ENCHA_OS:-?}"
    ;;
esac
