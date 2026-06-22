#!/usr/bin/env bash
# modules/12-gh.sh — GitHub CLI (gh).
set -euo pipefail
: "${ENCHA_LIB:?ENCHA_LIB não definido — rode via run.sh}"
# shellcheck source=../lib/common.sh
. "$ENCHA_LIB/common.sh"
# shellcheck source=../lib/detect.sh
. "$ENCHA_LIB/detect.sh"
# shellcheck source=../lib/pkg.sh
. "$ENCHA_LIB/pkg.sh"

load_brew_env || true
brew_install gh || die "falha ao instalar o gh."

log_success "GitHub CLI pronto."
log_info "Para conectar sua conta depois: rode 'gh auth login'."
