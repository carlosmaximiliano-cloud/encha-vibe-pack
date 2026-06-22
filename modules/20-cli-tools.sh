#!/usr/bin/env bash
# modules/20-cli-tools.sh — ferramentas de busca usadas no dia a dia e pelo
# próprio Claude Code: ripgrep (rg), fd e fzf. Instaladas via Homebrew para
# nomes/versões consistentes entre macOS e Linux.
set -euo pipefail
: "${ENCHA_LIB:?ENCHA_LIB não definido — rode via run.sh}"
# shellcheck source=../lib/common.sh
. "$ENCHA_LIB/common.sh"
# shellcheck source=../lib/detect.sh
. "$ENCHA_LIB/detect.sh"
# shellcheck source=../lib/pkg.sh
. "$ENCHA_LIB/pkg.sh"

load_brew_env || true

_ok=1
brew_install ripgrep || { log_warn "ripgrep falhou"; _ok=0; }
brew_install fd       || { log_warn "fd falhou"; _ok=0; }
brew_install fzf      || { log_warn "fzf falhou"; _ok=0; }

if [ "$_ok" = "1" ]; then
  log_success "ripgrep, fd e fzf prontos."
else
  log_warn "Algumas ferramentas de busca não foram instaladas — veja o log."
  exit 1
fi
