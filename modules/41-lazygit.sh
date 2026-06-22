#!/usr/bin/env bash
# modules/41-lazygit.sh — LazyGit: interface de terminal para git.
set -euo pipefail
: "${ENCHA_LIB:?ENCHA_LIB não definido — rode via run.sh}"
# shellcheck source=../lib/common.sh
. "$ENCHA_LIB/common.sh"
# shellcheck source=../lib/detect.sh
. "$ENCHA_LIB/detect.sh"
# shellcheck source=../lib/pkg.sh
. "$ENCHA_LIB/pkg.sh"

load_brew_env || true
brew_install lazygit || die "falha ao instalar o lazygit."

log_success "LazyGit pronto (rode 'lazygit' dentro de um repositório git)."
