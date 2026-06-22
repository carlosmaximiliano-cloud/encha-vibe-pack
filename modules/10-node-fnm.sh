#!/usr/bin/env bash
# modules/10-node-fnm.sh — Node.js via fnm (Fast Node Manager).
# Instala o fnm pelo Homebrew, configura o shell e instala o Node LTS.
set -euo pipefail
: "${ENCHA_LIB:?ENCHA_LIB não definido — rode via run.sh}"
# shellcheck source=../lib/common.sh
. "$ENCHA_LIB/common.sh"
# shellcheck source=../lib/detect.sh
. "$ENCHA_LIB/detect.sh"
# shellcheck source=../lib/pkg.sh
. "$ENCHA_LIB/pkg.sh"

load_brew_env || true
brew_install fnm || die "falha ao instalar o fnm."

# Persiste a configuração do fnm nos rc interativos.
persist_fnm_shellenv

if is_dry_run; then
  log_info "[dry-run] fnm install --lts && fnm default <lts>"
  exit 0
fi

# Carrega o fnm na sessão atual.
if command_exists fnm; then
  eval "$(fnm env --use-on-cd 2>/dev/null)" || true
else
  die "fnm não ficou disponível no PATH após a instalação."
fi

# Instala o Node LTS e define como padrão (idempotente).
fnm install --lts
fnm use --lts >/dev/null 2>&1 || true
_current="$(fnm current 2>/dev/null || echo '')"
if [ -n "$_current" ] && [ "$_current" != "none" ]; then
  fnm default "$_current" >/dev/null 2>&1 || true
fi

if command_exists node; then
  log_success "Node $(node -v) e npm $(npm -v 2>/dev/null || echo '?') prontos."
else
  log_warn "Node instalado via fnm — abra um novo terminal para ativá-lo."
fi
