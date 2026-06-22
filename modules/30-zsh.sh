#!/usr/bin/env bash
# modules/30-zsh.sh — instala o Zsh e, opcionalmente, define como shell padrão.
set -euo pipefail
: "${ENCHA_LIB:?ENCHA_LIB não definido — rode via run.sh}"
# shellcheck source=../lib/common.sh
. "$ENCHA_LIB/common.sh"
# shellcheck source=../lib/detect.sh
. "$ENCHA_LIB/detect.sh"
# shellcheck source=../lib/pkg.sh
. "$ENCHA_LIB/pkg.sh"

# No macOS o zsh já é o shell padrão desde o Catalina; ainda assim garantimos
# uma versão atual via brew (não substitui a do sistema).
load_brew_env || true
if ! command_exists zsh; then
  brew_install zsh || die "falha ao instalar o zsh."
else
  log_success "zsh já disponível ($(zsh --version 2>/dev/null | head -n1))."
fi

# Já é o shell de login?
current_shell="$(basename "${SHELL:-}")"
if [ "$current_shell" = "zsh" ]; then
  log_success "zsh já é o seu shell padrão."
  exit 0
fi

if is_dry_run; then
  log_info "[dry-run] ofereceria definir o zsh como shell padrão (chsh)."
  exit 0
fi

zsh_path="$(command -v zsh || true)"
[ -n "$zsh_path" ] || { log_warn "zsh não encontrado no PATH; pulando troca de shell."; exit 0; }

if confirm "Definir o zsh como seu shell padrão? (pode pedir sua senha)"; then
  # Garante que o zsh está listado em /etc/shells.
  if [ -w /etc/shells ] || command_exists sudo; then
    if ! grep -qxF "$zsh_path" /etc/shells 2>/dev/null; then
      printf '%s\n' "$zsh_path" | sudo_run tee -a /etc/shells >/dev/null || true
    fi
  fi
  if chsh -s "$zsh_path" 2>/dev/null; then
    log_success "Shell padrão alterado para zsh (vale no próximo login)."
  else
    log_warn "Não consegui trocar o shell automaticamente. Rode manualmente: chsh -s $zsh_path"
  fi
else
  log_info "Mantendo o shell atual ($current_shell)."
fi
