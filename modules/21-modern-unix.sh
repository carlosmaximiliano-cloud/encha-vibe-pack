#!/usr/bin/env bash
# modules/21-modern-unix.sh — substitutos modernos: bat (cat), eza (ls), zoxide (cd).
set -euo pipefail
: "${ENCHA_LIB:?ENCHA_LIB não definido — rode via run.sh}"
# shellcheck source=../lib/common.sh
. "$ENCHA_LIB/common.sh"
# shellcheck source=../lib/detect.sh
. "$ENCHA_LIB/detect.sh"
# shellcheck source=../lib/pkg.sh
. "$ENCHA_LIB/pkg.sh"

load_brew_env || true

brew_install bat    || log_warn "bat falhou"
brew_install eza    || log_warn "eza falhou"
brew_install zoxide || log_warn "zoxide falhou"

# Inicializa o zoxide nos shells (substitui o cd por uma versão "inteligente").
if command_exists zoxide || is_dry_run; then
  add_line_once "$HOME/.zshrc"  'eval "$(zoxide init zsh)"'
  add_line_once "$HOME/.bashrc" 'eval "$(zoxide init bash)"'
fi

# Aliases amigáveis (opcionais, não destrutivos).
add_line_once "$HOME/.zshrc"  'command -v eza >/dev/null 2>&1 && alias ls="eza --icons --group-directories-first"'
add_line_once "$HOME/.bashrc" 'command -v eza >/dev/null 2>&1 && alias ls="eza --icons --group-directories-first"'

log_success "bat, eza e zoxide configurados."
