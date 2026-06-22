#!/usr/bin/env bash
# modules/31-starship.sh — Starship: prompt rápido e bonito, multiplataforma.
set -euo pipefail
: "${ENCHA_LIB:?ENCHA_LIB não definido — rode via run.sh}"
# shellcheck source=../lib/common.sh
. "$ENCHA_LIB/common.sh"
# shellcheck source=../lib/detect.sh
. "$ENCHA_LIB/detect.sh"
# shellcheck source=../lib/pkg.sh
. "$ENCHA_LIB/pkg.sh"

load_brew_env || true
brew_install starship || die "falha ao instalar o starship."

# Ativa o starship nos shells (no fim do rc, para ter a última palavra no prompt).
add_line_once "$HOME/.zshrc"  'eval "$(starship init zsh)"'
add_line_once "$HOME/.bashrc" 'eval "$(starship init bash)"'

log_success "Starship instalado e ativado nos shells."
log_info "Os ícones do prompt exigem uma Nerd Font (módulo de fontes)."
