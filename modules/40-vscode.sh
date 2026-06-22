#!/usr/bin/env bash
# modules/40-vscode.sh — Visual Studio Code + extensão do Claude Code.
# No WSL, o VS Code roda no Windows: aqui apenas usamos o 'code' já exposto pelo
# Windows (se existir) para instalar a extensão.
set -euo pipefail
: "${ENCHA_LIB:?ENCHA_LIB não definido — rode via run.sh}"
# shellcheck source=../lib/common.sh
. "$ENCHA_LIB/common.sh"
# shellcheck source=../lib/detect.sh
. "$ENCHA_LIB/detect.sh"
# shellcheck source=../lib/pkg.sh
. "$ENCHA_LIB/pkg.sh"

install_vscode() {
  if command_exists code; then
    log_success "VS Code já disponível (comando 'code')."
    return 0
  fi
  if is_dry_run; then
    log_info "[dry-run] instalaria o VS Code conforme o SO."
    return 0
  fi

  case "${ENCHA_OS:-}" in
    macos)
      load_brew_env || true
      brew_install_cask visual-studio-code || return 1
      ;;
    wsl)
      log_warn "No WSL, instale o VS Code no WINDOWS: https://code.visualstudio.com/"
      log_info "Depois instale a extensão 'WSL' no VS Code e o comando 'code' ficará disponível aqui."
      return 1
      ;;
    linux)
      if command_exists snap; then
        sudo_run snap install code --classic || return 1
      elif [ "${ENCHA_NATIVE_PKG:-}" = "apt" ]; then
        # Repositório oficial da Microsoft.
        tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
        curl -fsSL https://packages.microsoft.com/keys/microsoft.asc -o "$tmp/ms.asc"
        gpg --dearmor < "$tmp/ms.asc" > "$tmp/microsoft.gpg"
        sudo_run install -D -o root -g root -m 644 "$tmp/microsoft.gpg" /usr/share/keyrings/microsoft.gpg
        echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
          | sudo_run tee /etc/apt/sources.list.d/vscode.list >/dev/null
        sudo_run apt-get update -y
        sudo_run apt-get install -y code || return 1
      elif [ "${ENCHA_NATIVE_PKG:-}" = "dnf" ]; then
        sudo_run rpm --import https://packages.microsoft.com/keys/microsoft.asc
        printf '[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc\n' \
          | sudo_run tee /etc/yum.repos.d/vscode.repo >/dev/null
        sudo_run dnf install -y code || return 1
      else
        log_warn "Não sei instalar o VS Code automaticamente nesta distro."
        log_info "Baixe em: https://code.visualstudio.com/"
        return 1
      fi
      ;;
    *)
      return 1
      ;;
  esac
}

if install_vscode; then
  log_success "VS Code pronto."
else
  log_warn "VS Code não foi instalado automaticamente (veja as instruções acima)."
fi

# Extensão do Claude Code (não-fatal: pode falhar se o 'code' não estiver no PATH).
if command_exists code && ! is_dry_run; then
  if code --list-extensions 2>/dev/null | grep -qi 'anthropic.claude-code'; then
    log_success "Extensão Claude Code já instalada no VS Code."
  else
    log_info "Instalando a extensão Claude Code no VS Code…"
    code --install-extension anthropic.claude-code >/dev/null 2>&1 \
      && log_success "Extensão Claude Code instalada." \
      || log_warn "Não consegui instalar a extensão automaticamente."
  fi
fi
log_info "Dica: ao rodar 'claude' no terminal integrado do VS Code, a integração é configurada sozinha."
