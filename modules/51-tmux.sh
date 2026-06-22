#!/usr/bin/env bash
# modules/51-tmux.sh — tmux + TPM (gerenciador de plugins). OPCIONAL.
set -euo pipefail
: "${ENCHA_LIB:?ENCHA_LIB não definido — rode via run.sh}"
# shellcheck source=../lib/common.sh
. "$ENCHA_LIB/common.sh"
# shellcheck source=../lib/detect.sh
. "$ENCHA_LIB/detect.sh"
# shellcheck source=../lib/pkg.sh
. "$ENCHA_LIB/pkg.sh"

load_brew_env || true
brew_install tmux || die "falha ao instalar o tmux."

# TPM — Tmux Plugin Manager.
tpm_dir="$HOME/.tmux/plugins/tpm"
if [ -d "$tpm_dir/.git" ]; then
  log_success "TPM já instalado."
else
  if is_dry_run; then
    log_info "[dry-run] clonaria o TPM em $tpm_dir"
  else
    git clone --depth 1 https://github.com/tmux-plugins/tpm "$tpm_dir" \
      && log_success "TPM instalado." \
      || log_warn "não consegui clonar o TPM."
  fi
fi

# ~/.tmux.conf mínimo, apenas se ainda não existir (não sobrescreve o do aluno).
conf="$HOME/.tmux.conf"
if [ ! -f "$conf" ] && ! is_dry_run; then
  cat > "$conf" <<'EOF'
# ~/.tmux.conf — base gerada pelo Encha Vibe Pack
set -g mouse on
set -g history-limit 10000
setw -g mode-keys vi

# Plugins (TPM)
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'

# Inicializa o TPM (mantenha esta linha por último)
run '~/.tmux/plugins/tpm/tpm'
EOF
  log_success "Criado ~/.tmux.conf base."
else
  log_info "Mantendo seu ~/.tmux.conf existente (não sobrescrevi)."
fi

log_info "Dentro do tmux, pressione 'prefix + I' para instalar os plugins."
