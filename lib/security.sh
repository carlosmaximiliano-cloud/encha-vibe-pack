#!/usr/bin/env bash
# lib/security.sh — utilidades de segurança: integridade (SHA-256) e download
# endurecido (apenas HTTPS, com verificação opcional). Requer lib/common.sh.

if [ -n "${ENCHA_SECURITY_SOURCED:-}" ]; then
  return 0 2>/dev/null || true
fi
ENCHA_SECURITY_SOURCED=1

# Calcula o SHA-256 de um arquivo (shasum no macOS, sha256sum no Linux).
sha256_of() {
  if command_exists shasum; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command_exists sha256sum; then
    sha256sum "$1" | awk '{print $1}'
  else
    return 1
  fi
}

# verify_sha256 <arquivo> <esperado> — 0 se confere.
verify_sha256() {
  local file="$1"; local expected="$2"; local got
  [ -n "$expected" ] || { log_warn "sem checksum esperado para $(basename "$file")"; return 1; }
  got="$(sha256_of "$file")" || { log_error "nenhuma ferramenta de SHA-256 disponível."; return 1; }
  if [ "$got" = "$expected" ]; then
    return 0
  fi
  log_error "checksum divergente em $(basename "$file"): esperado=$expected obtido=$got"
  return 1
}

# Recusa qualquer URL que não seja HTTPS.
require_https() {
  case "$1" in
    https://*) return 0 ;;
    *) log_error "URL recusada (somente HTTPS é permitido): $1"; return 1 ;;
  esac
}

# download_verified <url> <destino> [sha256]
# Baixa via HTTPS; se um SHA-256 for informado, verifica e aborta se divergir.
download_verified() {
  local url="$1"; local dest="$2"; local sha="${3:-}"
  require_https "$url" || return 1
  if is_dry_run; then
    log_info "[dry-run] baixaria $url"
    return 0
  fi
  curl -fsSL "$url" -o "$dest" || { log_error "falha ao baixar $url"; return 1; }
  if [ -n "$sha" ]; then
    verify_sha256 "$dest" "$sha" || return 1
    log_success "integridade verificada: $(basename "$dest")"
  fi
  return 0
}
