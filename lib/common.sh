#!/usr/bin/env bash
# lib/common.sh — helpers compartilhados: logging, prompts, execução segura.
#
# Este arquivo é "sourced" por scripts de entrada e por módulos. NÃO chamamos
# `set -e` aqui para não alterar o comportamento do shell que faz o source de
# forma surpreendente — os scripts de entrada (install.sh, run.sh, modules/*)
# é que definem o modo estrito.
#
# Compatível com bash 3.2 (padrão do macOS): sem mapfile, sem `declare -A`,
# sem `${var,,}` e sem namerefs.

# Evita sourcing duplicado.
if [ -n "${ENCHA_COMMON_SOURCED:-}" ]; then
  return 0 2>/dev/null || true
fi
ENCHA_COMMON_SOURCED=1

# --- Configuração global (defaults seguros sob `set -u`) ---
DRY_RUN="${DRY_RUN:-0}"
ASSUME_YES="${ASSUME_YES:-0}"
ENCHA_HOME="${ENCHA_HOME:-$HOME/.encha-vibe-pack}"
ENCHA_LOG_DIR="${ENCHA_LOG_DIR:-$ENCHA_HOME/logs}"
ENCHA_LOG_FILE="${ENCHA_LOG_FILE:-}"

# --- Cores (desativadas fora de TTY ou com NO_COLOR) ---
if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RESET=$'\033[0m';  C_BOLD=$'\033[1m';   C_DIM=$'\033[2m'
  C_RED=$'\033[31m';   C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m';  C_CYAN=$'\033[36m'
else
  C_RESET=''; C_BOLD=''; C_DIM=''
  C_RED='';   C_GREEN=''; C_YELLOW=''
  C_BLUE='';  C_CYAN=''
fi

# --- Logging (sempre em stderr, para não poluir o stdout usado pelo menu) ---
_log() {
  # $1 = cor, $2 = símbolo, resto = mensagem
  local color="$1"; local sym="$2"; shift 2
  local msg="$*"
  printf '%s%s%s %s\n' "$color" "$sym" "$C_RESET" "$msg" >&2
  if [ -n "${ENCHA_LOG_FILE:-}" ]; then
    printf '[%s] %s %s\n' "$(date '+%H:%M:%S')" "$sym" "$msg" >>"$ENCHA_LOG_FILE" 2>/dev/null || true
  fi
}
log_info()    { _log "$C_BLUE"            "•" "$@"; }
log_step()    { _log "$C_CYAN$C_BOLD"     "▶" "$@"; }
log_warn()    { _log "$C_YELLOW"          "!" "$@"; }
log_error()   { _log "$C_RED"             "x" "$@"; }
log_success() { _log "$C_GREEN"           "✓" "$@"; }

die() { log_error "$@"; exit 1; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

is_dry_run() { [ "${DRY_RUN:-0}" = "1" ]; }

# Há um terminal interativo REALMENTE utilizável? `[ -r /dev/tty ]` não basta:
# o arquivo pode existir e ter permissão, mas open() falhar (ENXIO) quando não
# há terminal controlador. Aqui tentamos abrir de fato, num subshell isolado.
tty_available() {
  ( exec </dev/tty ) >/dev/null 2>&1
}

# Confirmação interativa. Lê de /dev/tty para funcionar mesmo sob `curl | bash`.
# Respeita ASSUME_YES=1.
confirm() {
  local prompt="${1:-Continuar?}"
  if [ "${ASSUME_YES:-0}" = "1" ]; then
    return 0
  fi
  if ! tty_available; then
    # Sem terminal interativo e sem --yes: nega por segurança.
    log_warn "Sem terminal interativo; use --yes para automatizar."
    return 1
  fi
  local reply=""
  printf '%s%s%s [s/N] ' "$C_BOLD" "$prompt" "$C_RESET" >&2
  read -r reply </dev/tty || return 1
  case "$reply" in
    s|S|sim|SIM|Sim|y|Y|yes|YES|Yes) return 0 ;;
    *) return 1 ;;
  esac
}

# Executa um comando (vetor de argumentos), respeitando DRY_RUN e logando.
run_cmd() {
  if is_dry_run; then
    printf '%s[dry-run]%s %s\n' "$C_DIM" "$C_RESET" "$*" >&2
    return 0
  fi
  log_info "→ $*"
  "$@"
}

# --- Privilégios (sudo) com transparência ---
SUDO="${SUDO:-}"
need_sudo() {
  if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
  elif command_exists sudo; then
    SUDO="sudo"
  else
    die "Este passo precisa de administrador, mas 'sudo' não está disponível."
  fi
}

# Executa um comando como root, mostrando exatamente o que será rodado.
sudo_run() {
  need_sudo
  if is_dry_run; then
    printf '%s[dry-run]%s %s %s\n' "$C_DIM" "$C_RESET" "${SUDO:-(root)}" "$*" >&2
    return 0
  fi
  if [ -n "$SUDO" ]; then
    log_warn "Privilégio de administrador: $SUDO $*"
    $SUDO "$@"
  else
    log_info "→ $*"
    "$@"
  fi
}

# Adiciona uma linha a um arquivo apenas se ainda não existir (idempotente).
add_line_once() {
  local file="$1"; local line="$2"
  [ -n "$file" ] || return 0
  if is_dry_run; then
    log_info "[dry-run] garantir em $file: $line"
    return 0
  fi
  touch "$file" 2>/dev/null || return 0
  # -x: compara a LINHA inteira (não substring), evitando falsos positivos e
  # duplicatas quando uma linha é prefixo/substring de outra.
  if ! grep -qxF -- "$line" "$file" 2>/dev/null; then
    printf '\n# Adicionado pelo Encha Vibe Pack\n%s\n' "$line" >>"$file"
    log_info "Atualizado: $file"
  fi
}

# Inicializa o arquivo de log da execução.
init_log() {
  mkdir -p "$ENCHA_LOG_DIR" 2>/dev/null || true
  if [ -z "${ENCHA_LOG_FILE:-}" ]; then
    ENCHA_LOG_FILE="$ENCHA_LOG_DIR/install-$(date '+%Y%m%d-%H%M%S').log"
  fi
  if : >"$ENCHA_LOG_FILE" 2>/dev/null; then
    # Logs podem conter caminhos e detalhes da máquina — restringe a leitura ao dono.
    chmod 600 "$ENCHA_LOG_FILE" 2>/dev/null || true
    export ENCHA_LOG_FILE
  else
    ENCHA_LOG_FILE=""
  fi
}

# Trap de erro: reporta código e linha. Chamado pelos scripts de entrada.
_encha_on_error() {
  local code="$1"; local line="$2"
  log_error "Falha (código $code) próxima à linha $line."
  [ -n "${ENCHA_LOG_FILE:-}" ] && log_error "Log completo: $ENCHA_LOG_FILE"
  return 0
}
setup_error_trap() {
  trap '_encha_on_error "$?" "$LINENO"' ERR
}
