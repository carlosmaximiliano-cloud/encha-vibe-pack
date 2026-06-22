#!/usr/bin/env bash
# lib/ui.sh — interface de seleção: banner, catálogo, presets e menu interativo.
#
# Contrato de I/O: TODA a interface (banner, menus, prompts) é escrita em stderr
# e lê de /dev/tty. As funções que "retornam" listas de módulos imprimem APENAS
# os nomes de arquivo (um por linha) em stdout, para o chamador capturar com
#   while IFS= read -r m; do ...; done < <(funcao)
#
# Requer lib/common.sh carregado. Compatível com bash 3.2.

if [ -n "${ENCHA_UI_SOURCED:-}" ]; then
  return 0 2>/dev/null || true
fi
ENCHA_UI_SOURCED=1

# Catálogo de módulos em ordem de exibição/execução (prefixo numérico = ordem).
# Mantenha em sincronia com modules/ e com module_title().
catalog_modules() {
  cat <<'EOF'
00-prereqs.sh
01-homebrew.sh
10-node-fnm.sh
11-claude-code.sh
20-cli-tools.sh
21-modern-unix.sh
12-gh.sh
30-zsh.sh
31-starship.sh
32-zsh-plugins.sh
33-nerd-fonts.sh
40-vscode.sh
41-lazygit.sh
50-containers.sh
51-tmux.sh
60-python-uv.sh
EOF
}

# Rótulo legível de cada módulo.
module_title() {
  case "$1" in
    00-prereqs.sh)    echo "Pré-requisitos (git, curl, build tools)" ;;
    01-homebrew.sh)   echo "Homebrew (gerenciador de pacotes)" ;;
    10-node-fnm.sh)   echo "Node.js (via fnm)" ;;
    11-claude-code.sh) echo "Claude Code (CLI da Anthropic)" ;;
    20-cli-tools.sh)  echo "Busca no terminal (ripgrep, fd, fzf)" ;;
    21-modern-unix.sh) echo "Unix moderno (bat, eza, zoxide)" ;;
    12-gh.sh)         echo "GitHub CLI (gh)" ;;
    30-zsh.sh)        echo "Zsh (shell)" ;;
    31-starship.sh)   echo "Starship (prompt bonito)" ;;
    32-zsh-plugins.sh) echo "Plugins do Zsh (autosuggestions + highlight)" ;;
    33-nerd-fonts.sh) echo "Nerd Fonts (ícones no terminal)" ;;
    40-vscode.sh)     echo "VS Code + extensão Claude Code" ;;
    41-lazygit.sh)    echo "LazyGit (UI de git no terminal)" ;;
    50-containers.sh) echo "Containers (OrbStack no Mac / Docker no Linux)" ;;
    51-tmux.sh)       echo "tmux (multiplexador de terminal)" ;;
    60-python-uv.sh)  echo "Python (via uv)" ;;
    *)                echo "$1" ;;
  esac
}

print_banner() {
  local version="$1"; local oslabel="$2"
  {
    printf '\n'
    printf '%s' "$C_CYAN$C_BOLD"
    printf '  ███████╗███╗   ██╗ ██████╗██╗  ██╗ █████╗     ██╗   ██╗██╗██████╗ ███████╗\n'
    printf '  ██╔════╝████╗  ██║██╔════╝██║  ██║██╔══██╗    ██║   ██║██║██╔══██╗██╔════╝\n'
    printf '  █████╗  ██╔██╗ ██║██║     ███████║███████║    ██║   ██║██║██████╔╝█████╗  \n'
    printf '  ██╔══╝  ██║╚██╗██║██║     ██╔══██║██╔══██║    ╚██╗ ██╔╝██║██╔══██╗██╔══╝  \n'
    printf '  ███████╗██║ ╚████║╚██████╗██║  ██║██║  ██║     ╚████╔╝ ██║██████╔╝███████╗\n'
    printf '  ╚══════╝╚═╝  ╚═══╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝      ╚═══╝  ╚═╝╚═════╝ ╚══════╝\n'
    printf '%s' "$C_RESET"
    printf '  %sVibe Pack%s — ambiente para começar com Claude Code\n' "$C_BOLD" "$C_RESET"
    printf '  %sversão %s  •  %s%s\n\n' "$C_DIM" "$version" "$oslabel" "$C_RESET"
  } >&2
}

# Lê um preset (presets/<nome>.txt) e imprime os módulos válidos (um por linha).
# Ignora linhas em branco e comentários (#).
load_preset() {
  local name="$1"
  local file="$ENCHA_ROOT/presets/$name.txt"
  [ -f "$file" ] || return 1
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      ''|\#*) continue ;;
      *) printf '%s\n' "$line" ;;
    esac
  done < "$file"
}

# Conta quantos módulos um preset tem (para exibição).
_preset_count() {
  local n=0 line
  while IFS= read -r line; do n=$((n+1)); done < <(load_preset "$1")
  printf '%s' "$n"
}

# Menu principal. Imprime em stdout os módulos selecionados (um por linha).
interactive_select() {
  # Sem terminal interativo não há como exibir o menu. Em vez de tentar ler de
  # /dev/tty (o que, sob `set -e`, abortaria o script), orientamos o uso de um
  # preset e retornamos vazio (o chamador encerra educadamente).
  if ! tty_available; then
    log_error "Sem terminal interativo para exibir o menu."
    log_error "Use um preset: --preset rapido | recomendado | completo (ou rode dentro de um terminal)."
    return 0
  fi
  local choice=""
  while true; do
    {
      printf '%sEscolha um tier (preset) ou personalize:%s\n\n' "$C_BOLD" "$C_RESET"
      printf '  %s1%s) Rápido      — só o essencial p/ rodar o Claude Code (%s itens)\n' "$C_CYAN" "$C_RESET" "$(_preset_count rapido)"
      printf '  %s2%s) Recomendado — essencial + shell bonito + git/IDE (%s itens)\n' "$C_CYAN" "$C_RESET" "$(_preset_count recomendado)"
      printf '  %s3%s) Completo    — recomendado + containers, tmux, Python (%s itens)\n' "$C_CYAN" "$C_RESET" "$(_preset_count completo)"
      printf '  %s4%s) Personalizado — escolher item a item\n' "$C_CYAN" "$C_RESET"
      printf '  %s0%s) Cancelar\n\n' "$C_CYAN" "$C_RESET"
      printf 'Opção [2]: '
    } >&2
    read -r choice </dev/tty || { echo "" ; return 0; }
    [ -z "$choice" ] && choice="2"
    case "$choice" in
      1) _select_from_preset rapido;      return 0 ;;
      2) _select_from_preset recomendado; return 0 ;;
      3) _select_from_preset completo;    return 0 ;;
      4) _custom_select "";               return 0 ;;
      0) return 0 ;;
      *) log_warn "Opção inválida: $choice" ;;
    esac
  done
}

# Carrega um preset e oferece ajuste fino opcional.
_select_from_preset() {
  local preset="$1"
  if confirm "Deseja ajustar a seleção item a item antes de instalar?"; then
    _custom_select "$preset"
  else
    load_preset "$preset"
  fi
}

# Seleção customizada por checkbox. $1 = preset base (opcional) p/ pré-marcar.
# Imprime em stdout os módulos marcados.
_custom_select() {
  local base_preset="$1"

  # Monta arrays paralelos: ITEMS (arquivos) e MARK (0/1).
  local ITEMS=() MARK=()
  local m
  while IFS= read -r m; do
    [ -n "$m" ] && ITEMS+=("$m")
  done < <(catalog_modules)

  # Pré-marca conforme o preset base (se houver).
  local i preset_line marked
  for ((i=0; i<${#ITEMS[@]}; i++)); do
    MARK[$i]=0
  done
  if [ -n "$base_preset" ]; then
    while IFS= read -r preset_line; do
      for ((i=0; i<${#ITEMS[@]}; i++)); do
        if [ "${ITEMS[$i]}" = "$preset_line" ]; then MARK[$i]=1; fi
      done
    done < <(load_preset "$base_preset")
  fi

  local input token idx
  while true; do
    {
      printf '\n%sSeleção personalizada%s — digite os números para marcar/desmarcar.\n' "$C_BOLD" "$C_RESET"
      for ((i=0; i<${#ITEMS[@]}; i++)); do
        if [ "${MARK[$i]}" = "1" ]; then marked="${C_GREEN}[x]${C_RESET}"; else marked="[ ]"; fi
        printf '  %s %2d) %s\n' "$marked" "$((i+1))" "$(module_title "${ITEMS[$i]}")"
      done
      printf '\n  %sa%s=marcar todos  %sn%s=desmarcar todos  %sEnter%s=confirmar  %sq%s=cancelar\n' \
        "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET"
      printf 'Alternar (ex.: 1 3 5): '
    } >&2
    read -r input </dev/tty || break
    case "$input" in
      "") break ;;
      q|Q) return 0 ;;
      a|A) for ((i=0; i<${#ITEMS[@]}; i++)); do MARK[$i]=1; done ;;
      n|N) for ((i=0; i<${#ITEMS[@]}; i++)); do MARK[$i]=0; done ;;
      *)
        for token in $input; do
          case "$token" in
            *[!0-9]*) log_warn "ignorado: $token" ;;
            *)
              idx=$((token-1))
              if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#ITEMS[@]}" ]; then
                if [ "${MARK[$idx]}" = "1" ]; then MARK[$idx]=0; else MARK[$idx]=1; fi
              else
                log_warn "fora do intervalo: $token"
              fi
              ;;
          esac
        done
        ;;
    esac
  done

  # Emite os marcados.
  for ((i=0; i<${#ITEMS[@]}; i++)); do
    if [ "${MARK[$i]}" = "1" ]; then printf '%s\n' "${ITEMS[$i]}"; fi
  done
}
