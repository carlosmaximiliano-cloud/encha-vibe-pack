# Ferramentas do Encha Vibe Pack

> O que cada ferramenta faz, para quem serve, e o que você perde se decidir não instalar.

Este guia é para você tomar uma decisão informada antes (ou depois) de rodar o instalador.
Cada ferramenta tem uma seção honesta: se a perda for pequena, dizemos isso. Se for grande, também.

---

## Como ler este guia

As ferramentas estão organizadas pelo mesmo **tier** do menu do instalador:

| Tier | Comando | Para quem |
|------|---------|-----------|
| **Rápido** | `--preset rapido` | Só quero rodar o Claude Code agora |
| **Recomendado** | `--preset recomendado` | Quero um ambiente confortável para trabalhar |
| **Completo** | `--preset completo` | Quero tudo instalado e pronto |
| **Personalizado** | *(menu interativo)* | Escolho ferramenta a ferramenta |

Cada seção tem:
- **O que é** — explicação em uma linha, sem jargão
- **Para quem instalar** — perfil prático
- **O que você perde sem ela** — custo real, não exagero

---

## Base do sistema

> Instaladas automaticamente em **qualquer preset**. Não aparecem no menu porque são obrigatórias — tudo o que vem depois depende delas.

---

### Pré-requisitos do sistema

**O que é:** ferramentas de compilação nativas do seu SO.
No macOS são as **Xcode Command Line Tools**; no Linux/WSL são `build-essential`, `gcc`, `make` e similares.

**Para quem instalar:** todo mundo — são instaladas automaticamente.

**O que você perde sem ela:** o Homebrew (e praticamente tudo mais) não consegue compilar pacotes.
Você veria erros como `xcrun: error: invalid active developer path` (macOS) ou `gcc: command not found` (Linux) em cada instalação subsequente.

---

### Homebrew

**O que é:** o gestor de pacotes mais usado em macOS e Linux.
Em vez de baixar instaladores `.pkg` ou `.dmg` um a um, você instala qualquer ferramenta com `brew install nome`.

**Para quem instalar:** todo mundo — é a base de tudo.

**O que você perde sem ela:** cada ferramenta seguinte precisaria ser instalada manualmente, com seu próprio instalador, caminho e método de atualização. Viável, mas trabalhoso e difícil de manter consistente entre alunos.

> **Linux/WSL:** o instalador usa o Linuxbrew (mesma ferramenta, mesmo comando) para manter as instruções iguais para todos os SOs.

---

## Tier Rápido — o mínimo para rodar o Claude Code

> Instala em ~5 minutos. Suficiente para começar a usar o Claude Code no terminal hoje.

---

### Node.js (via fnm)

**O que é:** o ambiente de execução JavaScript que o Claude Code precisa para funcionar.
O **fnm** (Fast Node Manager) é o gerenciador de versões — permite instalar e trocar versões do Node com um comando.

**Para quem instalar:** todo mundo que vai usar o Claude Code (ou seja, todo mundo).

**O que você perde sem ela:** o Claude Code não instala — ele é distribuído como pacote npm e precisa do Node para rodar. Sem o fnm você instalaria o Node de forma global e menos flexível; com projetos que exigem versões diferentes, teria problemas.

---

### Claude Code CLI

**O que é:** a ferramenta principal — o `claude` que você digita no terminal para começar uma sessão com o assistente.

**Para quem instalar:** todo mundo.

**O que você perde sem ela:** não há como usar o Claude Code pelo terminal. Simples assim.

---

### Ferramentas de busca — ripgrep, fd, fzf

**O que são:**
- **ripgrep (`rg`)** — busca texto dentro de arquivos, muito mais rápido que o `grep` padrão
- **fd** — encontra arquivos por nome, mais rápido e intuitivo que o `find`
- **fzf** — filtro interativo: selecione qualquer coisa com busca fuzzy diretamente no terminal

**Para quem instalar:** todo mundo, especialmente quem vai trabalhar com projetos com muitos arquivos.

**O que você perde sem elas:**
O Claude Code usa o `ripgrep` e o `fd` internamente para navegar e entender o seu projeto. Sem eles, a busca cai para ferramentas mais lentas e a experiência fica degradada (respostas mais lentas, contexto de projeto menos preciso). O `fzf` é opcional para o Claude Code, mas vicia — uma vez que você filtra arquivos e histórico do shell com ele, é difícil voltar.

---

## Tier Recomendado — um ambiente confortável de verdade

> Adiciona shell moderno, IDE, e ferramentas de produtividade. O ponto de equilíbrio entre rapidez de instalação e qualidade de uso diário.

---

### bat, eza, zoxide

**O que são:** substitutos modernos de três comandos Unix clássicos:
- **bat** → substitui `cat` (exibe arquivos com syntax highlighting e números de linha)
- **eza** → substitui `ls` (lista arquivos com ícones, cores e info de git)
- **zoxide** → substitui `cd` (lembra os diretórios que você mais acessa; `z nomeprojeto` leva você lá direto)

**Para quem instalar:** quem passa mais do que alguns minutos por dia no terminal.

**O que você perde sem elas:** nada essencial — `cat`, `ls` e `cd` continuam funcionando. A perda é em conforto e velocidade de navegação. Se você mal abre o terminal, pode pular.

---

### GitHub CLI (`gh`)

**O que é:** a interface de linha de comando oficial do GitHub.
Cria repos, abre pull requests, lista issues, faz clone — tudo sem sair do terminal.

**Para quem instalar:** quem vai criar repositórios, colaborar em projetos ou usar o GitHub no dia a dia.

**O que você perde sem ela:** você usará a interface web do GitHub para operações de repo. Funciona, mas é mais lento. O Claude Code também pode usar o `gh` para criar repos e PRs diretamente durante uma sessão — sem ele, essas ações terão de ser feitas manualmente.

---

### Zsh

**O que é:** um shell mais moderno que o bash padrão. É o shell padrão do macOS desde 2019 e tem um ecossistema rico de plugins e temas.

**Para quem instalar:** quem vai usar o terminal regularmente. É a base para os plugins e o Starship abaixo.

**O que você perde sem ela:** você fica no bash padrão do sistema — que funciona, mas os plugins de autosugestão e syntax highlighting desta lista só funcionam bem no Zsh. Se pular o Zsh, os dois módulos seguintes (`32-zsh-plugins`) também perdem o efeito.

> **macOS:** o Zsh já é o shell padrão. O módulo garante uma versão atualizada via Homebrew e oferece configurar o Zsh do Homebrew como padrão (opcional).

---

### Starship

**O que é:** um prompt de terminal inteligente e bonito. Exibe automaticamente: branch git, status de alterações, versão do Node/Python/etc., duração do último comando, e mais.

**Para quem instalar:** quem trabalha com git, múltiplas linguagens, ou simplesmente quer saber o que está acontecendo sem precisar digitar `git status` o tempo todo.

**O que você perde sem ela:** o terminal fica com o prompt padrão (normalmente só `$` ou `usuario@maquina`). Você perde o contexto visual que te diz, por exemplo, que está na branch `main` com 3 arquivos modificados — informação que evita commits acidentais.

---

### Plugins do Zsh — autosuggestions e syntax-highlighting

**O que são:**
- **zsh-autosuggestions** — sugere, em cinza, o comando do histórico que você provavelmente quer digitar. Pressione `→` para aceitar.
- **zsh-syntax-highlighting** — colore o comando enquanto você digita: verde se o comando existe, vermelho se não existe, e assim por diante.

**Para quem instalar:** quem usa o terminal com frequência e digita os mesmos comandos repetidamente.

**O que você perde sem elas:** você digita tudo do zero sempre, e só descobre que um comando está errado depois de apertar Enter. São plugins pequenos com impacto grande no dia a dia.

> Requerem Zsh instalado para funcionar.

---

### Nerd Fonts — FiraCode

**O que é:** uma fonte monospace (ideal para código) com ícones Unicode extras embutidos.
O Starship e o eza usam esses ícones para exibir `  main` (em vez de `git: main`) e ícones de tipo de arquivo.

**Para quem instalar:** quem instalou o Starship e o eza e quer que os ícones apareçam corretamente.

**O que você perde sem ela:** os ícones aparecem como `?` ou quadradinhos (`□`) no terminal. O resto funciona normalmente — é puramente visual.

> **WSL:** fontes precisam ser instaladas no **Windows** (não no Linux). O instalador exibe o link direto para baixar e instalar manualmente — é um clique só.
>
> **Linux nativo:** o instalador baixa e instala automaticamente em `~/.local/share/fonts/`.

---

### VS Code + extensão Claude Code

**O que é:** o editor de código mais popular do mundo, com a extensão oficial do Claude Code instalada.
A extensão traz o assistente direto para dentro do editor — você pode pedir ajuda, explicações e edições sem sair do VS Code.

**Para quem instalar:** quem prefere trabalhar em um editor visual a usar o terminal puro. É especialmente útil para iniciantes que ainda estão se acostumando com o ambiente de desenvolvimento.

**O que você perde sem ela:** você precisará usar o Claude Code só pelo terminal (`claude` no bash/zsh) ou pela interface web. Funciona, mas sem a integração direta com o arquivo aberto no editor. Se já tem o VS Code instalado, o módulo instala apenas a extensão.

> **WSL:** o VS Code roda no **Windows**. O instalador detecta isso e orienta a instalar a versão Windows (com a extensão WSL da Microsoft). Se você já tem o VS Code no Windows, só a extensão Claude Code é instalada.

---

### LazyGit

**O que é:** uma interface visual para o git que roda no próprio terminal (TUI). Você navega commits, stages, branches e merges com o teclado — sem precisar decorar os comandos git.

**Para quem instalar:** quem acha o git confuso ou comete erros no terminal (adicionar arquivo errado, esquecer de commitar, etc.). Ótimo para iniciantes.

**O que você perde sem ela:** você usa o `git` pela linha de comando normalmente. Funcional, mas exige conhecer os comandos. Se você já é confortável com git CLI, pode pular tranquilo.

---

## Tier Completo — para quem quer tudo pronto

> Adiciona ferramentas para workflows mais avançados. Recomendado se você já sabe que vai precisar de containers, sessões persistentes de terminal ou Python.

---

### Containers — OrbStack (macOS) / Docker (Linux/WSL)

**O que é:** o runtime de containers que permite rodar aplicações isoladas com `docker run` e `docker compose`.
- **macOS:** instala o **OrbStack**, uma alternativa ao Docker Desktop — mais leve, mais rápido, sem taxa de licença para uso pessoal.
- **Linux/WSL:** instala o **Docker Engine** (open source, sem interface gráfica, ideal para servidores e WSL).

**Para quem instalar:** quem vai rodar bancos de dados locais, APIs, ambientes de desenvolvimento isolados, ou qualquer projeto que use `docker-compose`.

**O que você perde sem ela:** sem runtime de containers, comandos como `docker run`, `docker compose up` e similares falham. Se o seu projeto não usa containers, você não perde nada.

> **WSL:** o instalador orienta a instalar o **Docker Desktop no Windows** com integração WSL2 habilitada — esse é o caminho recomendado pela Microsoft para WSL.

---

### tmux + TPM

**O que é:** um multiplexador de terminal — ele divide uma janela de terminal em várias e mantém sessões vivas mesmo depois de fechar o terminal.
O **TPM** (Tmux Plugin Manager) facilita instalar plugins para o tmux.

**Para quem instalar:** quem trabalha com múltiplos contextos ao mesmo tempo (ex.: um painel com o servidor rodando, outro com o editor, outro com o git) ou precisa deixar processos rodando e desconectar.

**O que você perde sem ela:** você usa abas do seu terminal de sempre. Funciona bem para a maioria dos iniciantes — o tmux tem uma curva de aprendizado e só vale a pena se você vai usá-lo de fato.

> O instalador cria um `.tmux.conf` mínimo **apenas se você não tiver um**. Configurações existentes não são tocadas.

---

### Python (via uv)

**O que é:** o **uv** é um gerenciador de pacotes e ambientes Python ultrarrápido (substitui pip, venv e pyenv em um único comando). O módulo instala o uv e usa ele para instalar uma versão gerenciada do Python.

**Para quem instalar:** quem vai escrever código Python ou usar ferramentas que dependem de Python (ex.: alguns agentes e pipelines de IA).

**O que você perde sem ela:** você precisa instalar o Python manualmente (pelo site oficial, Homebrew, ou pyenv) e gerenciar ambientes virtuais com `venv`/`pip` clássicos. Funciona, mas o `uv` é significativamente mais rápido e moderno — e é o que a comunidade de IA/ML está adotando agora.

---

## Tabela resumo

| Ferramenta | Tier | macOS | Linux | WSL | Sem ela você perde... |
|------------|------|:-----:|:-----:|:---:|----------------------|
| Pré-requisitos | Base | auto | auto | auto | Compiladores — nada mais instala |
| Homebrew | Base | auto | auto | auto | Gestor de pacotes — tudo manual |
| Node.js + fnm | Rápido | ✓ | ✓ | ✓ | Claude Code não instala |
| Claude Code CLI | Rápido | ✓ | ✓ | ✓ | O produto em si |
| ripgrep, fd, fzf | Rápido | ✓ | ✓ | ✓ | Busca rápida; contexto de projeto no Claude |
| bat, eza, zoxide | Recomendado | ✓ | ✓ | ✓ | Conforto no terminal (cat/ls/cd clássicos ficam) |
| GitHub CLI | Recomendado | ✓ | ✓ | ✓ | Operações de repo pela linha; integração com Claude Code |
| Zsh | Recomendado | ✓ | ✓ | ✓ | Base dos plugins abaixo |
| Starship | Recomendado | ✓ | ✓ | ✓ | Contexto visual (branch, versão, status) |
| Plugins Zsh | Recomendado | ✓ | ✓ | ✓ | Autosugestão e coloração de comandos |
| Nerd Fonts | Recomendado | ✓ | ✓ | manual¹ | Ícones viram `?` no terminal |
| VS Code + extensão | Recomendado | ✓ | ✓ | parcial² | IDE integrada ao Claude |
| LazyGit | Recomendado | ✓ | ✓ | ✓ | Interface visual do git (git CLI fica) |
| OrbStack / Docker | Completo | OrbStack | Docker | guide³ | Runtime de containers |
| tmux + TPM | Completo | ✓ | ✓ | ✓ | Sessões e painéis persistentes |
| Python + uv | Completo | ✓ | ✓ | ✓ | Gestor moderno de Python |

**Notas:**
1. **WSL / Nerd Fonts:** fontes são instaladas no Windows — o instalador exibe o link e as instruções.
2. **WSL / VS Code:** o VS Code roda no Windows; o instalador orienta a instalação e instala a extensão se o comando `code` estiver disponível.
3. **WSL / Docker:** recomendado usar o Docker Desktop no Windows com integração WSL2 — o instalador explica os passos.
