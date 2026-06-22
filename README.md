# Encha Vibe Pack

> Instalador local de ferramentas para quem está **começando com o Claude Code**.
> Um comando, um menu, você escolhe o que instalar. Funciona em **macOS, Linux e Windows (via WSL2)**.

O Encha Vibe Pack prepara a máquina do aluno com o essencial para programar com o
Claude Code — sem despejar uma stack gigante. Você decide **o quê** instalar, seja
por um **tier pronto** (rápido) ou marcando **item a item**.

---

## 🚀 Instalação

> Pré-requisito: o repositório precisa estar publicado no GitHub com uma _tag_
> (ex.: `v0.1.0`). Veja [Publicar uma versão](#-publicar-uma-versão).

### macOS / Linux / WSL2

```bash
curl -fsSL https://raw.githubusercontent.com/carlosmaximiliano-cloud/encha-vibe-pack/v0.1.0/install.sh | bash
```

### Windows (configura o WSL2 automaticamente)

Abra o **PowerShell como Administrador** e rode:

```powershell
irm https://raw.githubusercontent.com/carlosmaximiliano-cloud/encha-vibe-pack/v0.1.0/install.ps1 | iex
```

O script habilita o WSL2, instala o Ubuntu e roda o instalador lá dentro.
Pode pedir um **reinício** — depois é só rodar o comando de novo (ele continua de onde parou).

---

## 🎚️ Tiers (presets)

| Tier | Para quem | O que instala |
|------|-----------|---------------|
| **Rápido** | Só quero rodar o Claude Code | Pré-requisitos, Homebrew, Node (fnm), Claude Code, ripgrep/fd/fzf |
| **Recomendado** | Quero um ambiente confortável | Rápido + Zsh, Starship, plugins, Nerd Fonts, bat/eza/zoxide, GitHub CLI, VS Code + extensão, LazyGit |
| **Completo** | Quero tudo | Recomendado + containers (OrbStack/Docker), tmux, Python (uv) |
| **Personalizado** | Eu escolho | Marque/desmarque cada item no menu |

Você também pode pular o menu:

```bash
# direto num preset, sem perguntas
curl -fsSL .../install.sh | bash -s -- --preset rapido --yes
```

---

## 🧰 Ferramentas incluídas

- **Base:** Homebrew, Node.js (via [fnm](https://github.com/Schniz/fnm)), Claude Code
- **Terminal/busca:** ripgrep, fd, fzf, bat, eza, zoxide
- **Shell:** Zsh, [Starship](https://starship.rs), zsh-autosuggestions, zsh-syntax-highlighting, Nerd Fonts (FiraCode)
- **Git/IDE:** GitHub CLI (`gh`), VS Code + extensão Claude Code, LazyGit
- **Opcionais:** OrbStack (mac) / Docker (Linux), tmux + TPM, Python via [uv](https://github.com/astral-sh/uv)

> No **WSL**, o VS Code e as fontes ficam do lado do **Windows** — o instalador avisa e orienta.

Para detalhes sobre cada ferramenta — o que faz, para quem serve e o que você perde sem ela — veja o [Guia completo das ferramentas](docs/ferramentas.md).

---

## ⚙️ Opções da linha de comando

```
--preset <nome>   Instala um preset sem menu: rapido | recomendado | completo
--yes, -y         Não pergunta confirmações (modo não-interativo)
--dry-run         Mostra o que faria, sem instalar nada
--list            Lista os módulos disponíveis e sai
--no-color        Desativa cores
-h, --help        Ajuda
```

---

## 🔒 Segurança

Levamos a sério rodar coisas na máquina do aluno:

- **Baixe e inspecione antes de rodar** (recomendado). Em vez do `| bash`, baixe e leia:
  ```bash
  curl -fsSL https://raw.githubusercontent.com/carlosmaximiliano-cloud/encha-vibe-pack/v0.1.0/install.sh -o install.sh
  less install.sh        # leia
  bash install.sh        # rode
  ```
- **Tag fixa, não `main`.** O bootstrap baixa sempre uma versão _tagueada_ e imutável.
- **Verificação de integridade.** O tarball é conferido por **SHA-256** antes de rodar.
  Downloads de binários usam **somente HTTPS** (`lib/security.sh`).
- **`sudo` transparente.** Só pedimos administrador quando necessário e **mostramos o comando** antes de executá-lo.
- **Idempotente.** Rodar de novo não quebra nada: o que já existe é detectado e pulado.
- **Sem telemetria.** Nada é enviado para lugar nenhum. Logs ficam só na sua máquina, em `~/.encha-vibe-pack/logs/`.

> Exceções documentadas: o **Homebrew** e o **Docker** são instalados pelos seus
> instaladores **oficiais** (HTTPS), que são o método padrão e auditável da comunidade.

### Modelo de confiança (seja honesto consigo)

Como qualquer instalador de "uma linha" (`curl | bash`, `irm | iex`), a **raiz de confiança**
é o **HTTPS do GitHub + a tag fixa**:

- A verificação **SHA-256** protege contra **corrupção/troca do tarball** no transporte — **não**
  contra um comprometimento do próprio repositório (isso afetaria qualquer instalador). Por isso a
  recomendação de **baixar e inspecionar** acima, e de conferir o hash publicado nas _release notes_.
- **Redes corporativas/escolares** podem fazer inspeção de SSL: nesse caso o certificado visto é o
  da instituição, não o do GitHub. Se a origem parecer estranha, confirme com o TI antes de rodar.
- O `irm | iex` no Windows **roda independentemente da ExecutionPolicy** (é uma expressão, não um
  script em disco) — isso é esperado; a proteção é o HTTPS + abrir como Administrador conscientemente.
- O que o instalador **nunca faz:** baixar de `http://`, pedir senha fora do `sudo` do sistema, ou
  rodar como root (ele recusa root, porque o Homebrew não roda como root).

---

## 🧑‍💻 Desenvolvimento / uso local

Clonou o repositório? Rode direto, sem rede (o `install.sh` detecta o checkout):

```bash
git clone https://github.com/carlosmaximiliano-cloud/encha-vibe-pack.git
cd encha-vibe-pack
./run.sh --dry-run            # veja o menu e simule
./run.sh --preset recomendado # instale um preset
```

Estrutura:

```
install.sh    Bootstrap (uma linha) — baixa a tag, verifica e roda
install.ps1   Bootstrap Windows — configura o WSL2 e roda o install.sh
run.sh        Orquestrador: menu, dependências, execução, resumo
lib/          common (log/exec) · detect (SO) · pkg (brew/apt) · ui (menu) · security
modules/      Um script idempotente por ferramenta (NN-nome.sh)
presets/      Listas de módulos por tier
tools/        update-checksum.sh (gera o SHA-256 do release)
```

Convenções: tudo em **bash compatível com 3.2** (o macOS ainda traz 3.2), entradas
interativas sempre via `/dev/tty`, e cada módulo roda **isolado** em seu próprio processo.

---

## 📦 Publicar uma versão

```bash
# 1) Atualize a versão
echo "0.1.0" > VERSION
# garanta que ENCHA_REF em install.sh aponta para a tag (ex.: v0.1.0)

# 2) Crie e envie a tag
git tag v0.1.0 && git push origin v0.1.0

# 3) Gere o checksum do tarball e grave no install.sh
tools/update-checksum.sh v0.1.0

# 4) Faça commit do install.sh + checksums.txt atualizados
git commit -am "release v0.1.0 (checksum)" && git push
```

A partir daí, o one-liner com `v0.1.0` passa a validar a integridade automaticamente.

---

## ✅ Requisitos

- **macOS** 12+ (Intel ou Apple Silicon)
- **Linux** com `apt`, `dnf` ou `pacman`
- **Windows** 10 (2004+) ou 11, com suporte a `wsl --install`

---

Feito com 💚 para a turma da **Encha**.
