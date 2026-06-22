#!/usr/bin/env bash
# modules/50-containers.sh — ambiente de containers (OPCIONAL).
#   macOS  -> OrbStack (leve, rápido; substitui o Docker Desktop)
#   Linux  -> Docker Engine (instalador oficial get.docker.com)
#   WSL    -> orienta a usar o Docker Desktop do Windows (integração WSL2)
set -euo pipefail
: "${ENCHA_LIB:?ENCHA_LIB não definido — rode via run.sh}"
# shellcheck source=../lib/common.sh
. "$ENCHA_LIB/common.sh"
# shellcheck source=../lib/detect.sh
. "$ENCHA_LIB/detect.sh"
# shellcheck source=../lib/pkg.sh
. "$ENCHA_LIB/pkg.sh"

case "${ENCHA_OS:-}" in
  macos)
    load_brew_env || true
    if command_exists docker || [ -d "/Applications/OrbStack.app" ]; then
      log_success "Já há um runtime de containers instalado."
      exit 0
    fi
    brew_install_cask orbstack || die "falha ao instalar o OrbStack."
    log_success "OrbStack instalado. Abra o app uma vez para finalizar a configuração."
    ;;

  wsl)
    if command_exists docker; then
      log_success "Docker já disponível no WSL."
      exit 0
    fi
    log_warn "No WSL2, o caminho recomendado é o Docker Desktop no Windows."
    log_info "Instale o Docker Desktop e ative a integração com esta distro em:"
    log_info "  Settings → Resources → WSL Integration."
    log_info "Download: https://www.docker.com/products/docker-desktop/"
    ;;

  linux)
    if command_exists docker; then
      log_success "Docker já instalado ($(docker --version 2>/dev/null || echo ok))."
      exit 0
    fi
    if is_dry_run; then
      log_info "[dry-run] instalaria o Docker Engine (get.docker.com) e adicionaria seu usuário ao grupo docker."
      exit 0
    fi
    if ! confirm "Instalar o Docker Engine agora? (usa o instalador oficial get.docker.com)"; then
      log_info "Pulando containers."
      exit 0
    fi
    # NOTA: get.docker.com é o instalador oficial e auditável do Docker (HTTPS).
    tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
    curl -fsSL https://get.docker.com -o "$tmp/get-docker.sh" || die "falha ao baixar o instalador do Docker."
    sudo_run sh "$tmp/get-docker.sh"
    # Permite usar docker sem sudo (vale no próximo login).
    sudo_run usermod -aG docker "$USER" || log_warn "não consegui adicionar $USER ao grupo docker."
    log_success "Docker instalado. Saia e entre na sessão (ou reinicie) para usar sem sudo."
    ;;

  *)
    log_warn "SO não suportado para containers: ${ENCHA_OS:-?}"
    ;;
esac
