#!/usr/bin/env bash
# modules/32-zsh-plugins.sh — plugins de produtividade do Zsh:
#   - zsh-autosuggestions (sugestões cinza enquanto você digita)
#   - zsh-syntax-highlighting (colore comandos válidos/ inválidos)
set -euo pipefail
: "${ENCHA_LIB:?ENCHA_LIB não definido — rode via run.sh}"
# shellcheck source=../lib/common.sh
. "$ENCHA_LIB/common.sh"
# shellcheck source=../lib/detect.sh
. "$ENCHA_LIB/detect.sh"
# shellcheck source=../lib/pkg.sh
. "$ENCHA_LIB/pkg.sh"

load_brew_env || true
brew_install zsh-autosuggestions     || log_warn "zsh-autosuggestions falhou"
brew_install zsh-syntax-highlighting || log_warn "zsh-syntax-highlighting falhou"

prefix="$(brew --prefix 2>/dev/null || echo '/opt/homebrew')"
sug="$prefix/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
syn="$prefix/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# autosuggestions primeiro; syntax-highlighting deve ser o ÚLTIMO a ser carregado.
add_line_once "$HOME/.zshrc" "[ -f \"$sug\" ] && source \"$sug\""
add_line_once "$HOME/.zshrc" "[ -f \"$syn\" ] && source \"$syn\""

log_success "Plugins do Zsh configurados."
