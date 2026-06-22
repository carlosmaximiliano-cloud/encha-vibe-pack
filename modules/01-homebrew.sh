#!/usr/bin/env bash
# modules/01-homebrew.sh — instala o Homebrew (macOS e Linux/WSL via Linuxbrew).
# Idempotente: se já existir, apenas carrega o ambiente.
set -euo pipefail
: "${ENCHA_LIB:?ENCHA_LIB não definido — rode via run.sh}"
# shellcheck source=../lib/common.sh
. "$ENCHA_LIB/common.sh"
# shellcheck source=../lib/detect.sh
. "$ENCHA_LIB/detect.sh"
# shellcheck source=../lib/pkg.sh
. "$ENCHA_LIB/pkg.sh"

if load_brew_env && command_exists brew; then
  log_success "Homebrew já instalado ($(brew --version 2>/dev/null | head -n1))."
  persist_brew_shellenv
  exit 0
fi

if is_dry_run; then
  log_info "[dry-run] instalaria o Homebrew via instalador oficial e persistiria o shellenv."
  exit 0
fi

# NOTA DE SEGURANÇA: usamos o instalador OFICIAL do Homebrew, sobre HTTPS.
# É o método padrão e auditável da comunidade; reimplementá-lo seria menos
# estável e menos seguro. NONINTERACTIVE evita prompts durante a automação.
log_info "Instalando o Homebrew (instalador oficial)…"
NONINTERACTIVE=1 /bin/bash -c \
  "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

load_brew_env || die "Homebrew foi instalado, mas não consegui carregar o ambiente (brew shellenv)."
persist_brew_shellenv

log_success "Homebrew instalado ($(brew --version 2>/dev/null | head -n1))."
