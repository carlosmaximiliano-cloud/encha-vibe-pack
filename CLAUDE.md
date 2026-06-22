# CLAUDE.md — Encha Vibe Pack

Instalador local de ferramentas para iniciantes em Claude Code. Bash modular,
multiplataforma (macOS / Linux / WSL2). **Não é** o `Instalador-Encha` (aquele é
setup de servidor + painel Next.js) — são projetos separados.

## Arquitetura

- `install.sh` — bootstrap (uma linha). Em checkout local roda direto; senão baixa
  o tarball da tag fixa, verifica SHA-256 e executa `run.sh`.
- `install.ps1` — bootstrap Windows: configura WSL2 + Ubuntu e chama o `install.sh` dentro do WSL.
- `run.sh` — orquestrador: parse de args, seleção (preset/menu), resolução de
  dependências, execução isolada de cada módulo, resumo.
- `lib/` — `common.sh` (log/exec/confirm/`tty_available`), `detect.sh` (SO/distro/arch),
  `pkg.sh` (brew + apt/dnf/pacman), `ui.sh` (menu), `security.sh` (sha256/https).
- `modules/NN-nome.sh` — um por ferramenta. Idempotente. Roda em **subprocesso próprio**
  e re-importa as libs via `$ENCHA_LIB`.
- `presets/*.txt` — listas de módulos por tier.

## Convenções (importantes)

- **Compatível com bash 3.2** (padrão do macOS): sem `mapfile`/`readarray`, sem
  `declare -A`, sem `${var,,}`, sem namerefs. Use `while read` + arrays indexados.
- **Entrada interativa só via `/dev/tty`** e sempre depois de checar `tty_available`
  (o `[ -r /dev/tty ]` não basta: `open()` pode falhar com ENXIO sob `set -e`).
- **Logs em stderr**; stdout é reservado para "retornos" (ex.: o menu emite os
  módulos escolhidos em stdout).
- **Estratégia de pacotes:** gerenciador nativo só para os pré-requisitos; o resto
  via **Homebrew** (mac e Linux) para nomes/versões consistentes.
- **Segurança:** tag fixa, SHA-256 do tarball, downloads só HTTPS, `sudo` mostrado
  antes de rodar, sem telemetria. Homebrew/Docker via instaladores oficiais (exceção documentada).

## Testes locais (sem instalar nada)

```bash
./run.sh --list
./run.sh --preset completo --dry-run --yes --no-color
bash -n install.sh run.sh lib/*.sh modules/*.sh   # sintaxe
```

CI roda ShellCheck + `bash -n` em `.github/workflows/shellcheck.yml`.

## Ao adicionar uma ferramenta

1. Crie `modules/NN-nome.sh` (copie o cabeçalho de outro módulo; mantenha idempotência).
2. Registre em `lib/ui.sh`: `catalog_modules()` (ordem) e `module_title()` (rótulo).
3. Inclua nos `presets/*.txt` que fizerem sentido.
4. Se tiver dependências, trate em `run.sh` (seção "Resolução de dependências").
