#!/usr/bin/env bash
# run.sh — orquestrador do Encha Vibe Pack.
#
# Decide o conjunto de módulos (por preset ou menu interativo), resolve
# dependências, confirma o plano e executa cada módulo de forma isolada.
#
# Uso:
#   run.sh [--preset rapido|recomendado|completo] [--yes] [--dry-run]
#          [--list] [--no-color] [--help]

set -euo pipefail

ENCHA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENCHA_LIB="$ENCHA_ROOT/lib"
export ENCHA_ROOT ENCHA_LIB

# Sanity check: confirma que as libs estão presentes antes de qualquer source.
if [ ! -f "$ENCHA_LIB/common.sh" ] || [ ! -f "$ENCHA_LIB/ui.sh" ]; then
  printf 'erro: instalação corrompida — não encontrei %s\n' "$ENCHA_LIB/common.sh" >&2
  exit 1
fi

# shellcheck source=lib/common.sh
. "$ENCHA_LIB/common.sh"
# shellcheck source=lib/detect.sh
. "$ENCHA_LIB/detect.sh"
# shellcheck source=lib/ui.sh
. "$ENCHA_LIB/ui.sh"

VERSION="$(cat "$ENCHA_ROOT/VERSION" 2>/dev/null || echo "0.0.0")"

usage() {
  cat >&2 <<EOF
Encha Vibe Pack ${VERSION}

Uso: run.sh [opções]

Opções:
  --preset <nome>   Instala um preset sem menu: rapido | recomendado | completo
  --yes, -y         Não pergunta confirmações (modo não-interativo; também aceita o aviso)
  --accept-risk     Aceita o aviso de isenção de responsabilidade sem perguntar
  --dry-run         Mostra o que faria, sem instalar nada
  --list            Lista os módulos disponíveis e sai
  --no-color        Desativa cores
  -h, --help        Mostra esta ajuda

Variáveis de ambiente:
  ENCHA_ACCEPT_RISK=1   Aceita o aviso (útil para automação sem terminal)
EOF
}

list_modules() {
  local m
  while IFS= read -r m; do
    [ -n "$m" ] && printf '  %-20s %s\n' "$m" "$(module_title "$m")"
  done < <(catalog_modules)
}

# --- Parsing de argumentos ---
PRESET=""
DO_LIST=0
ACCEPT_RISK="${ACCEPT_RISK:-0}"
while [ $# -gt 0 ]; do
  case "$1" in
    --preset)      PRESET="${2:-}"; shift 2 ;;
    --preset=*)    PRESET="${1#*=}"; shift ;;
    --yes|-y)      ASSUME_YES=1; shift ;;
    --accept-risk) ACCEPT_RISK=1; shift ;;
    --dry-run)     DRY_RUN=1; shift ;;
    --no-color)    NO_COLOR=1; shift ;;
    --list)        DO_LIST=1; shift ;;
    -h|--help)     usage; exit 0 ;;
    *)             log_warn "argumento ignorado: $1"; shift ;;
  esac
done
export ASSUME_YES DRY_RUN

if [ "$DO_LIST" = "1" ]; then
  list_modules
  exit 0
fi

# Guard de root (cedo, ANTES de criar qualquer arquivo): o Homebrew se RECUSA a
# rodar como root, e criar logs/configs como root bagunça as permissões do $HOME.
# Override consciente: ENCHA_ALLOW_ROOT=1 (ex.: contêiner sem usuário comum).
if [ "$(id -u)" -eq 0 ] && [ "${ENCHA_ALLOW_ROOT:-0}" != "1" ]; then
  die "Não rode como root nem com sudo. O Homebrew não roda como root.
   Rode como seu usuário normal:  ./run.sh   (ou: curl ... | bash)
   Em último caso (contêiner sem usuário comum): ENCHA_ALLOW_ROOT=1 ./run.sh"
fi

init_log
setup_error_trap
detect_all

print_banner "$VERSION" "$(os_label)"

# --- Aviso de isenção de responsabilidade (sempre exibido) ---
# Aceite via: ENCHA_ACCEPT_RISK=1, --accept-risk, --yes (ASSUME_YES) ou "s" no prompt.
print_disclaimer
if [ "${ENCHA_ACCEPT_RISK:-0}" != "1" ] && [ "${ACCEPT_RISK:-0}" != "1" ]; then
  if ! confirm "Você concorda em prosseguir, por sua conta e risco?"; then
    die "É preciso aceitar os termos para continuar.
   Para automatizar (sem terminal), defina ENCHA_ACCEPT_RISK=1."
  fi
fi

case "${ENCHA_OS:-unknown}" in
  macos|linux|wsl) : ;;
  windows) die "No Windows nativo use o install.ps1 (ele configura o WSL2 e roda lá dentro)." ;;
  *) die "Sistema operacional não suportado: ${ENCHA_OS:-desconhecido}." ;;
esac

if is_dry_run; then
  log_warn "Modo dry-run: nada será instalado de fato."
fi

# --- Membership helpers (bash 3.2: usamos string com uma linha por item) ---
SELECTED_SET=""
set_contains() { printf '%s\n' "$SELECTED_SET" | grep -qxF -- "$1"; }
set_add()      { set_contains "$1" || SELECTED_SET="${SELECTED_SET}${1}
"; }

# --- Coleta a seleção (preset ou menu) ---
collect() {
  local m
  if [ -n "$PRESET" ]; then
    if ! load_preset "$PRESET" >/dev/null 2>&1; then
      die "preset inválido: '$PRESET' (use rapido | recomendado | completo)."
    fi
    while IFS= read -r m; do [ -n "$m" ] && set_add "$m"; done < <(load_preset "$PRESET")
  else
    while IFS= read -r m; do [ -n "$m" ] && set_add "$m"; done < <(interactive_select)
  fi
}

# --- Executa um módulo isolado em um subprocesso (atualiza OK/FAIL globais) ---
run_module() {
  local mod="$1"
  local path="$ENCHA_ROOT/modules/$mod"
  if [ ! -f "$path" ]; then
    log_warn "módulo ausente: $mod (pulando)"
    return 0
  fi
  log_step "$(module_title "$mod")"
  if bash "$path"; then
    OK_COUNT=$((OK_COUNT+1))
    return 0
  fi
  # Falhou:
  case "$mod" in
    00-prereqs.sh|01-homebrew.sh)
      die "Falha em passo crítico ($mod). Abortando — corrija e rode novamente."
      ;;
    *)
      FAIL_COUNT=$((FAIL_COUNT+1))
      FAILED_LIST="${FAILED_LIST}  - $(module_title "$mod")
"
      log_warn "Falha em '$mod' — seguindo com os demais."
      ;;
  esac
}

# Modo "one-shot": com --preset (automação) ou sem terminal, roda uma vez e sai.
# Caso contrário, ao terminar oferece voltar ao menu principal (como no Windows).
oneshot_mode() { [ -n "$PRESET" ] || ! tty_available; }

# --- Laço principal: seleção → plano → execução → resumo, repetível pelo menu ---
ANY_FAIL=0
while true; do
  SELECTED_SET=""
  collect

  # Nada selecionado (inclui "0) Cancelar" no menu) → encerra.
  if [ -z "$(printf '%s' "$SELECTED_SET" | tr -d '[:space:]')" ]; then
    log_warn "Nenhum item selecionado. Encerrando."
    break
  fi

  # --- Resolução de dependências (idempotentes; sempre seguras de incluir) ---
  # Qualquer instalação exige pré-requisitos + Homebrew.
  set_add "00-prereqs.sh"
  set_add "01-homebrew.sh"
  # Claude Code precisa de Node.
  if set_contains "11-claude-code.sh"; then set_add "10-node-fnm.sh"; fi
  # Starship e plugins do Zsh ficam melhores com o Zsh instalado.
  if set_contains "31-starship.sh" || set_contains "32-zsh-plugins.sh"; then set_add "30-zsh.sh"; fi

  # --- Ordena pela ordem do catálogo (respeita dependências por prefixo) ---
  ORDERED=""
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    if set_contains "$m"; then ORDERED="${ORDERED}${m}
"; fi
  done < <(catalog_modules)

  # --- Mostra o plano e confirma ---
  PLAN_COUNT=0
  log_step "Plano de instalação:"
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    PLAN_COUNT=$((PLAN_COUNT+1))
    printf '   %s%2d.%s %s\n' "$C_DIM" "$PLAN_COUNT" "$C_RESET" "$(module_title "$m")" >&2
  done < <(printf '%s' "$ORDERED")
  printf '\n' >&2

  if ! confirm "Iniciar a instalação destes ${PLAN_COUNT} itens?"; then
    log_warn "Cancelado."
    # Interativo: volta ao menu para reselecionar. Automação: encerra.
    if oneshot_mode; then break; fi
    continue
  fi

  # --- Executa cada módulo isolado ---
  OK_COUNT=0
  FAIL_COUNT=0
  FAILED_LIST=""
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    run_module "$m"
  done < <(printf '%s' "$ORDERED")

  # --- Resumo ---
  printf '\n' >&2
  log_step "Resumo"
  log_success "Concluídos: $OK_COUNT"
  if [ "$FAIL_COUNT" -gt 0 ]; then
    log_warn "Com falha: $FAIL_COUNT"
    printf '%s' "$FAILED_LIST" >&2
    ANY_FAIL=1
  fi
  [ -n "${ENCHA_LOG_FILE:-}" ] && log_info "Log: $ENCHA_LOG_FILE"
  log_info "Dica: feche e reabra o terminal para carregar as novas configurações de shell."

  # --- Voltar ao menu? (só interativo; automação roda uma vez e sai) ---
  if oneshot_mode; then break; fi
  printf '\n' >&2
  prompt_yes_no "Voltar ao menu principal?" || break
  printf '\n' >&2
done

if [ "$ANY_FAIL" -gt 0 ]; then exit 1; fi
exit 0
