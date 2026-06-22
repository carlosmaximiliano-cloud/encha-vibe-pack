#!/usr/bin/env bash
# lib/pkg.sh — abstração de instalação de pacotes.
#
# Estratégia (estabilidade > variedade): usamos o gerenciador NATIVO
# (apt/dnf/pacman) apenas para os pré-requisitos necessários até o Homebrew
# existir. Depois disso, instalamos as ferramentas via Homebrew tanto no macOS
# quanto no Linux/WSL (Linuxbrew) — assim os nomes de pacote e versões ficam
# consistentes entre os SOs, evitando as armadilhas de nomenclatura do apt
# (ex.: fd-find/fdfind, bat/batcat).
#
# Requer lib/common.sh e lib/detect.sh já carregados.

if [ -n "${ENCHA_PKG_SOURCED:-}" ]; then
  return 0 2>/dev/null || true
fi
ENCHA_PKG_SOURCED=1

# Atualiza índices do gerenciador nativo (best-effort, idempotente).
native_update() {
  case "${ENCHA_NATIVE_PKG:-none}" in
    apt)    sudo_run apt-get update -y ;;
    pacman) sudo_run pacman -Sy --noconfirm ;;
    dnf|brew|none|*) : ;;
  esac
}

# Instala 1+ pacotes via gerenciador NATIVO. Usado por 00-prereqs.
native_install() {
  [ "$#" -gt 0 ] || return 0
  case "${ENCHA_NATIVE_PKG:-none}" in
    apt)    sudo_run apt-get install -y "$@" ;;
    dnf)    sudo_run dnf install -y "$@" ;;
    pacman) sudo_run pacman -S --needed --noconfirm "$@" ;;
    brew)   brew install "$@" ;;
    *)      die "gerenciador nativo não suportado para instalar: $*" ;;
  esac
}

# --- Homebrew -------------------------------------------------------------

has_brew() { command_exists brew; }

# Localiza o binário do brew nos caminhos conhecidos (mac Intel/ARM, Linuxbrew).
_brew_bin() {
  local b
  for b in \
    /opt/homebrew/bin/brew \
    /usr/local/bin/brew \
    /home/linuxbrew/.linuxbrew/bin/brew \
    "$HOME/.linuxbrew/bin/brew"
  do
    if [ -x "$b" ]; then printf '%s\n' "$b"; return 0; fi
  done
  command_exists brew && { command -v brew; return 0; }
  return 1
}

# Carrega o ambiente do brew na sessão atual (PATH etc.).
load_brew_env() {
  local b
  b="$(_brew_bin)" || return 1
  eval "$("$b" shellenv)"
  return 0
}

# Persiste o shellenv do brew nos perfis de shell (idempotente).
persist_brew_shellenv() {
  local b; b="$(_brew_bin)" || return 0
  local line="eval \"\$(\"$b\" shellenv)\""
  local f
  for f in "$HOME/.zprofile" "$HOME/.bash_profile" "$HOME/.profile"; do
    add_line_once "$f" "$line"
  done
}

# Persiste o ambiente do fnm nos rc interativos (idempotente).
persist_fnm_shellenv() {
  local line='eval "$(fnm env --use-on-cd)"'
  local f
  for f in "$HOME/.zshrc" "$HOME/.bashrc"; do
    add_line_once "$f" "$line"
  done
}

# Instala uma fórmula via brew, se ainda não instalada (idempotente).
brew_install() {
  local formula="$1"
  has_brew || load_brew_env || { log_error "Homebrew indisponível para instalar $formula"; return 1; }
  if brew list --formula "$formula" >/dev/null 2>&1; then
    log_success "$formula já instalado."
    return 0
  fi
  if is_dry_run; then
    log_info "[dry-run] brew install $formula"
    return 0
  fi
  log_info "Instalando $formula via brew…"
  brew install "$formula"
}

# Instala um cask (apenas macOS).
brew_install_cask() {
  local cask="$1"
  if [ "${ENCHA_OS:-}" != "macos" ]; then
    log_warn "$cask ignorado (cask é apenas para macOS)."
    return 0
  fi
  has_brew || load_brew_env || { log_error "Homebrew indisponível para instalar $cask"; return 1; }
  if brew list --cask "$cask" >/dev/null 2>&1; then
    log_success "$cask já instalado."
    return 0
  fi
  if is_dry_run; then
    log_info "[dry-run] brew install --cask $cask"
    return 0
  fi
  log_info "Instalando $cask via brew (cask)…"
  brew install --cask "$cask"
}
