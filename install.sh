#!/usr/bin/env bash
# install.sh — Bootstrap do Encha Vibe Pack.
#
# Uso (uma linha) em macOS / Linux / WSL2:
#   curl -fsSL https://raw.githubusercontent.com/<user>/encha-vibe-pack/<tag>/install.sh | bash
#
# Fluxo:
#   1) Se rodando de dentro de uma cópia local do projeto (lib/ e run.sh ao lado),
#      executa direto, sem rede (modo desenvolvimento).
#   2) Caso contrário, baixa o tarball da TAG fixa, verifica o SHA-256, extrai em
#      ~/.encha-vibe-pack/<tag> e executa run.sh.
#
# Segurança: a tag é fixa (nunca "main"); se o checksum estiver embutido, ele é
# obrigatório. Sem checksum (build de desenvolvimento), pede confirmação antes
# de prosseguir — a menos que ENCHA_ALLOW_UNVERIFIED=1.

set -euo pipefail

# --- Configuração do release (preenchida ao publicar uma tag) ---
ENCHA_REPO="${ENCHA_REPO:-carlosmaximiliano-cloud/encha-vibe-pack}"
ENCHA_REF="${ENCHA_REF:-v0.2.2}"                     # tag fixa
ENCHA_TARBALL_SHA256="${ENCHA_TARBALL_SHA256:-0b02a474b8067dc8275703d333082e704de9612599420d330c9dbea75043c2c3}"     # SHA-256 do tarball (v0.2.2)
ENCHA_HOME="${ENCHA_HOME:-$HOME/.encha-vibe-pack}"

say() { printf '%s\n' "$*" >&2; }
die() { printf 'erro: %s\n' "$*" >&2; exit 1; }

print_disclaimer() {
  local Y='\033[1;33m' R='\033[0m' B='\033[1m'
  printf '\n' >&2
  printf "${Y}  ┌─────────────────────────────────────────────────────────────┐${R}\n" >&2
  printf "${Y}  │${R}  ⚠   AVISO — leia antes de prosseguir                    ${Y}│${R}\n" >&2
  printf "${Y}  ├─────────────────────────────────────────────────────────────┤${R}\n" >&2
  printf "${Y}  │${R}                                                             ${Y}│${R}\n" >&2
  printf "${Y}  │${R}  O Encha Vibe Pack é ${B}GRATUITO${R}, está em ${B}VERSÃO BETA${R} e é     ${Y}│${R}\n" >&2
  printf "${Y}  │${R}  fornecido ${B}SEM QUALQUER GARANTIA${R} (licença MIT).          ${Y}│${R}\n" >&2
  printf "${Y}  │${R}                                                             ${Y}│${R}\n" >&2
  printf "${Y}  │${R}  O que ele faz na sua máquina:                             ${Y}│${R}\n" >&2
  printf "${Y}  │${R}  • Instala pacotes via Homebrew, npm e gestores nativos    ${Y}│${R}\n" >&2
  printf "${Y}  │${R}  • Edita ~/.zshrc e ~/.bashrc                              ${Y}│${R}\n" >&2
  printf "${Y}  │${R}                                                             ${Y}│${R}\n" >&2
  printf "${Y}  │${R}  Ao prosseguir, você assume os riscos pelo uso.            ${Y}│${R}\n" >&2
  printf "${Y}  │${R}                                                             ${Y}│${R}\n" >&2
  printf "${Y}  └─────────────────────────────────────────────────────────────┘${R}\n" >&2
  printf '\n' >&2
}

confirm_disclaimer() {
  [ "${ENCHA_ACCEPT_RISK:-0}" = "1" ] && return 0
  if ! ( exec </dev/tty ) >/dev/null 2>&1; then
    die "sem terminal interativo. Para automatizar, defina ENCHA_ACCEPT_RISK=1."
  fi
  printf '  Deseja continuar com a instalação? [s/N] ' >&2
  local r; read -r r </dev/tty || die "abortado."
  case "$r" in
    s|S|sim|y|Y|yes) return 0 ;;
    *) die "Instalação cancelada." ;;
  esac
}

# Diretório deste script em disco (vazio sob curl|bash).
self_dir() {
  local src="${BASH_SOURCE[0]:-}"
  [ -n "$src" ] || return 1
  ( cd "$(dirname "$src")" 2>/dev/null && pwd ) || return 1
}

sha256_of() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    return 1
  fi
}

main() {
  # 1) Modo local (checkout): roda direto.
  local d
  if d="$(self_dir)" && [ -f "$d/run.sh" ] && [ -d "$d/lib" ]; then
    say "▶ Encha Vibe Pack — modo local ($d)"
    exec bash "$d/run.sh" "$@"
  fi

  # 2) Modo remoto.
  print_disclaimer
  confirm_disclaimer

  command -v curl >/dev/null 2>&1 || die "curl é necessário para o bootstrap."
  command -v tar  >/dev/null 2>&1 || die "tar é necessário para o bootstrap."

  # Valida REPO/REF (podem vir de env): evita que metacaracteres entrem na URL e,
  # no Windows, sejam repassados ao 'bash -lc' dentro do WSL.
  printf '%s' "$ENCHA_REPO" | grep -qE '^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$' \
    || die "ENCHA_REPO inválido: '$ENCHA_REPO' (esperado: owner/repo)."
  printf '%s' "$ENCHA_REF" | grep -qE '^[A-Za-z0-9._-]+$' \
    || die "ENCHA_REF inválido: '$ENCHA_REF'."
  # Coerência com "tag fixa, nunca uma branch": branches só com opt-in explícito.
  case "$ENCHA_REF" in
    main|master|HEAD|develop|dev|latest)
      [ "${ENCHA_ALLOW_UNVERIFIED:-0}" = "1" ] \
        || die "ENCHA_REF aponta para uma branch ('$ENCHA_REF'). Use uma tag (ex.: v0.1.0) ou defina ENCHA_ALLOW_UNVERIFIED=1." ;;
  esac

  local url="https://codeload.github.com/${ENCHA_REPO}/tar.gz/refs/tags/${ENCHA_REF}"
  local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/encha.XXXXXX")"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" EXIT
  local tgz="$tmp/encha.tar.gz"

  say "▶ Baixando Encha Vibe Pack ${ENCHA_REF}…"
  curl -fsSL "$url" -o "$tgz" || die "falha ao baixar $url"

  # Verificação de integridade.
  if [ -n "$ENCHA_TARBALL_SHA256" ]; then
    local got; got="$(sha256_of "$tgz")" || die "não há ferramenta de SHA-256 para verificar a integridade."
    if [ "$got" != "$ENCHA_TARBALL_SHA256" ]; then
      die "checksum NÃO confere — abortando. esperado=$ENCHA_TARBALL_SHA256 obtido=$got"
    fi
    say "✓ Integridade verificada (SHA-256)."
  fi

  # Defesa contra path traversal: recusa entradas com caminho absoluto ou "..".
  if tar -tzf "$tgz" | grep -qE '(^/|(^|/)\.\.(/|$))'; then
    die "tarball contém caminhos inseguros (absolutos ou '..') — abortando."
  fi

  local dest="$ENCHA_HOME/${ENCHA_REF}"
  mkdir -p "$dest"
  # --no-same-owner: não restaura dono/grupo do tarball (relevante se rodar como root).
  tar -xzf "$tgz" -C "$dest" --strip-components=1 --no-same-owner
  say "✓ Extraído em $dest"

  exec bash "$dest/run.sh" "$@"
}

main "$@"
