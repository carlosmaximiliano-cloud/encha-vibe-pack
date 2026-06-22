#!/usr/bin/env bash
# modules/11-claude-code.sh — instala o Claude Code (CLI da Anthropic) via npm.
set -euo pipefail
: "${ENCHA_LIB:?ENCHA_LIB não definido — rode via run.sh}"
# shellcheck source=../lib/common.sh
. "$ENCHA_LIB/common.sh"
# shellcheck source=../lib/detect.sh
. "$ENCHA_LIB/detect.sh"
# shellcheck source=../lib/pkg.sh
. "$ENCHA_LIB/pkg.sh"

load_brew_env || true
# Garante fnm/Node na sessão atual.
if command_exists fnm; then
  eval "$(fnm env 2>/dev/null)" || true
fi

if command_exists claude; then
  log_success "Claude Code já instalado ($(claude --version 2>/dev/null || echo 'ok'))."
  exit 0
fi

if ! command_exists npm; then
  die "npm não encontrado — instale o módulo Node (fnm) antes do Claude Code."
fi

if is_dry_run; then
  log_info "[dry-run] npm install -g @anthropic-ai/claude-code"
  exit 0
fi

log_info "Instalando o Claude Code via npm…"
npm install -g @anthropic-ai/claude-code

if command_exists claude; then
  log_success "Claude Code instalado ($(claude --version 2>/dev/null || echo 'ok'))."
  log_info "Para começar: abra um terminal, vá até a pasta de um projeto e rode 'claude'."
else
  log_warn "Claude Code instalado via npm — abra um novo terminal e rode 'claude'."
fi
