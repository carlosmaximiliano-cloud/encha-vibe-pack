#!/usr/bin/env bash
# modules/60-python-uv.sh — uv: gerenciador de Python/pacotes ultrarrápido. OPCIONAL.
set -euo pipefail
: "${ENCHA_LIB:?ENCHA_LIB não definido — rode via run.sh}"
# shellcheck source=../lib/common.sh
. "$ENCHA_LIB/common.sh"
# shellcheck source=../lib/detect.sh
. "$ENCHA_LIB/detect.sh"
# shellcheck source=../lib/pkg.sh
. "$ENCHA_LIB/pkg.sh"

load_brew_env || true
brew_install uv || die "falha ao instalar o uv."

if is_dry_run; then
  log_info "[dry-run] uv python install (instalaria uma versão recente do Python)."
  exit 0
fi

# Instala uma versão recente e estável do Python gerenciada pelo uv.
if command_exists uv; then
  uv python install >/dev/null 2>&1 \
    && log_success "uv pronto e Python instalado ($(uv python list 2>/dev/null | head -n1))." \
    || log_warn "uv instalado, mas não consegui instalar o Python agora (rode 'uv python install')."
fi

log_info "Use: 'uv venv' para criar ambientes e 'uv pip install <pacote>'."
