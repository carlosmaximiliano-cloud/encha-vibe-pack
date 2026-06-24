# Requires PowerShell 5.1+  (diretiva #Requires removida: invalida em scriptblock dinamico via irm)
<#
.SYNOPSIS
  Bootstrap do Encha Vibe Pack no Windows.

.DESCRIPTION
  Dois modos:

  - NATIVO (padrão): instala o Claude Code (instalador oficial, auto-atualizável,
    sem Node nem WSL) e as demais ferramentas via winget, e ajusta o perfil do
    PowerShell. Menos fricção para iniciantes — abra o PowerShell e use 'claude'.

  - WSL (avançado, -Mode wsl): habilita o WSL2 + Ubuntu e roda o instalador bash
    lá dentro. Necessário só para quem quer ambiente Linux completo / sandbox.

  TESTE MANUAL (não há como testar Windows fora de uma máquina Windows):
    - Nativo, tier Rápido: instala Claude Code + Git + busca, SEM Node; 'claude' funciona.
    - Nativo, reexecução: itens já instalados são pulados (idempotente).
    - -Mode wsl: fluxo antigo (WSL) intacto.

.PARAMETER Mode
  native (padrão) | wsl.

.PARAMETER Preset
  Preset a instalar sem menu: rapido | recomendado | completo. Vazio = menu interativo.

.PARAMETER Distro
  (Só no -Mode wsl) Distribuição WSL a usar/instalar (padrão: Ubuntu).

.EXAMPLE
  # No PowerShell (modo nativo, recomendado):
  irm https://raw.githubusercontent.com/<user>/encha-vibe-pack/<tag>/install.ps1 | iex

.EXAMPLE
  # Modo WSL (avançado) — abra o PowerShell COMO ADMINISTRADOR:
  & ([scriptblock]::Create((irm https://raw.githubusercontent.com/<user>/encha-vibe-pack/<tag>/install.ps1))) -Mode wsl
#>
[CmdletBinding()]
param(
  [ValidateSet('native', 'wsl')]
  [string]$Mode = 'native',
  [ValidateSet('', 'rapido', 'recomendado', 'completo')]
  [string]$Preset = '',
  [string]$Distro = 'Ubuntu',
  [switch]$AllowUnverified,
  [switch]$AcceptRisk
)

$ErrorActionPreference = 'Stop'
# Garante saída UTF-8 no console (acentos corretos mesmo no Windows PowerShell 5.1).
try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch {}
# Faz o wsl.exe emitir UTF-8 (em vez de UTF-16LE), evitando lixo no parsing.
$env:WSL_UTF8 = '1'

# --- Configuração do release (mesma do install.sh) ---
$Repo = $env:ENCHA_REPO; if (-not $Repo) { $Repo = 'carlosmaximiliano-cloud/encha-vibe-pack' }
$Ref  = $env:ENCHA_REF;  if (-not $Ref)  { $Ref  = 'v0.2.8' }
$Url  = "https://raw.githubusercontent.com/$Repo/$Ref/install.sh"
$ClaudeInstallUrl = 'https://claude.ai/install.ps1'

# --- Saída amigável ---
function Write-Step($msg)    { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)      { Write-Host "[ok] $msg"  -ForegroundColor Green }
function Write-WarnMsg($msg) { Write-Host "[!] $msg"   -ForegroundColor Yellow }
function Write-ErrMsg($msg)  { Write-Host "[x] $msg"   -ForegroundColor Red }

# --- Encerramento seguro ---
# 'exit' encerra o HOST atual: rodado in-process (one-liner do README via scriptblock),
# fecharia a janela do usuário. Em vez disso, registramos o código e lançamos um sentinela
# que é capturado no try/catch de nível superior; só chamamos 'exit' de verdade quando NÃO
# há console interativo (CI/pipe), preservando o exit code para automação.
$script:EnchaExitCode = 0
function Stop-Encha([int]$code = 0) {
  $script:EnchaExitCode = $code
  throw 'ENCHA_STOP'
}

# --- Validação de entradas (defesa em profundidade; valores podem vir de env) ---
function Assert-Inputs {
  if ($Repo -notmatch '^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$') {
    Write-ErrMsg "ENCHA_REPO inválido: '$Repo' (esperado: owner/repo)."; Stop-Encha 1
  }
  if ($Ref -notmatch '^[A-Za-z0-9._-]+$') {
    Write-ErrMsg "ENCHA_REF inválido: '$Ref'."; Stop-Encha 1
  }
  if ($Distro -notmatch '^[A-Za-z0-9 ._-]+$') {
    Write-ErrMsg "Distro inválida: '$Distro'."; Stop-Encha 1
  }
  if (($Ref -in @('main','master','HEAD','develop','dev','latest')) -and (-not $AllowUnverified)) {
    Write-ErrMsg "ENCHA_REF aponta para uma branch ('$Ref'). Use uma tag (ex.: v0.1.0) ou passe -AllowUnverified."
    Stop-Encha 1
  }
}

# --- Aviso de isenção de responsabilidade (ciente do modo) ---
function Show-Disclaimer {
  param([switch]$Wsl)
  $inner = 60
  $body = @(
    '',
    'Este instalador e GRATUITO, esta em VERSAO BETA e e',
    'fornecido SEM QUALQUER GARANTIA (licenca MIT).',
    '',
    'O que ele faz na sua maquina:'
  )
  if ($Wsl) {
    $body += '  - Habilita o WSL2 e instala o Ubuntu (pode reiniciar)'
    $body += '  - Instala pacotes e edita configs de shell no Linux'
  } else {
    $body += '  - Instala apps via winget (Claude Code, Git, VS Code...)'
    $body += '  - Edita seu perfil do PowerShell (Starship, sugestoes)'
  }
  $body += ''
  $body += 'Ao prosseguir, voce assume os riscos pelo uso.'
  $body += ''

  $border = '  +' + ('-' * $inner) + '+'
  Write-Host ''
  Write-Host $border -ForegroundColor Yellow
  Write-Host ('  |' + (' !  AVISO -- leia antes de prosseguir').PadRight($inner) + '|') -ForegroundColor Yellow
  Write-Host $border -ForegroundColor Yellow
  foreach ($l in $body) {
    Write-Host ('  |' + (' ' + $l).PadRight($inner) + '|') -ForegroundColor Yellow
  }
  Write-Host $border -ForegroundColor Yellow
  Write-Host ''
}

# Garante o aceite do aviso. Aceita via -AcceptRisk, env ENCHA_ACCEPT_RISK=1,
# -Preset (análogo ao --yes) ou resposta interativa (default = Não).
function Confirm-Risk {
  param([switch]$Wsl)
  Show-Disclaimer -Wsl:$Wsl
  if ($AcceptRisk -or ($env:ENCHA_ACCEPT_RISK -eq '1') -or $Preset) { return }
  if (-not (Test-Interactive)) {
    Write-ErrMsg 'Sem terminal interativo para confirmar o aviso.'
    Write-Host   'Rode de novo aceitando os termos, ex.: .\install.ps1 -AcceptRisk -Preset rapido' -ForegroundColor White
    Write-Host   '(ou defina $env:ENCHA_ACCEPT_RISK=1).' -ForegroundColor White
    Stop-Encha 1
  }
  $ans = Read-Host 'Voce concorda em prosseguir, por sua conta e risco? [s/N]'
  if ($ans -notmatch '^(s|sim|y|yes)$') {
    Write-ErrMsg 'E preciso aceitar os termos para continuar.'
    Write-Host   'Para automatizar, defina $env:ENCHA_ACCEPT_RISK=1 ou passe -AcceptRisk.' -ForegroundColor White
    Stop-Encha 1
  }
}

function Test-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p  = New-Object Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

# Há um console que aceita digitação? (false quando a entrada está redirecionada/piped,
# ex.: 'irm ... | iex' ou execução sem terminal — evita que Read-Host trave para sempre.)
function Test-Interactive {
  try { return (-not [Console]::IsInputRedirected) } catch { return $false }
}

# ============================ TRILHA NATIVA (winget) ============================

# Garante o winget disponível; senão, orienta instalar o App Installer.
function Test-Winget {
  if (Get-Command winget -ErrorAction SilentlyContinue) { return $true }
  Write-ErrMsg 'winget não encontrado nesta máquina.'
  Write-Host   'Instale o "App Installer" pela Microsoft Store (ou atualize o Windows) e rode de novo:' -ForegroundColor White
  Write-Host   '  https://aka.ms/getwinget' -ForegroundColor White
  return $false
}

# Mapa (ordem do catálogo) módulo -> ação no Windows. Única duplicação Windows-específica.
# Type: winget | claude | profile | skip.  SkipInTiers: pula o módulo nesses presets.
function Get-WingetMap {
  return @(
    [pscustomobject]@{ Module='00-prereqs.sh';     Type='winget';  Label='Git for Windows';                       Ids=@('Git.Git') }
    [pscustomobject]@{ Module='01-homebrew.sh';    Type='skip';    Label='Homebrew';                              Reason='no Windows o winget já é o gerenciador' }
    [pscustomobject]@{ Module='10-node-fnm.sh';    Type='winget';  Label='Node.js LTS';                           Ids=@('OpenJS.NodeJS.LTS'); SkipInTiers=@('rapido') }
    [pscustomobject]@{ Module='11-claude-code.sh'; Type='claude';  Label='Claude Code (instalador nativo)' }
    [pscustomobject]@{ Module='20-cli-tools.sh';   Type='winget';  Label='Busca no terminal (ripgrep, fd, fzf)';  Ids=@('BurntSushi.ripgrep.MSVC','sharkdp.fd','junegunn.fzf') }
    [pscustomobject]@{ Module='21-modern-unix.sh'; Type='winget';  Label='Unix moderno (bat, eza, zoxide)';       Ids=@('sharkdp.bat','eza-community.eza','ajeetdsouza.zoxide'); Profile=@('Invoke-Expression (& { (zoxide init powershell | Out-String) })') }
    [pscustomobject]@{ Module='12-gh.sh';          Type='winget';  Label='GitHub CLI (gh)';                       Ids=@('GitHub.cli') }
    [pscustomobject]@{ Module='30-zsh.sh';         Type='winget';  Label='PowerShell 7 (shell moderno)';          Ids=@('Microsoft.PowerShell') }
    [pscustomobject]@{ Module='31-starship.sh';    Type='winget';  Label='Starship (prompt bonito)';              Ids=@('Starship.Starship'); Profile=@('Invoke-Expression (&starship init powershell)') }
    [pscustomobject]@{ Module='32-zsh-plugins.sh'; Type='profile'; Label='Sugestões no PowerShell (PSReadLine)';  Profile=@('Set-PSReadLineOption -PredictionSource History','Set-PSReadLineOption -PredictionViewStyle ListView') }
    [pscustomobject]@{ Module='33-nerd-fonts.sh';  Type='winget';  Label='Nerd Font (FiraCode)';                  Ids=@('DEVCOM.FiraCodeNerdFont') }
    [pscustomobject]@{ Module='40-vscode.sh';      Type='winget';  Label='VS Code + extensão Claude Code';        Ids=@('Microsoft.VisualStudioCode'); VscodeExt='anthropic.claude-code' }
    [pscustomobject]@{ Module='41-lazygit.sh';     Type='winget';  Label='LazyGit';                               Ids=@('JesseDuffield.lazygit') }
    [pscustomobject]@{ Module='50-containers.sh';  Type='winget';  Label='Docker Desktop';                        Ids=@('Docker.DockerDesktop') }
    [pscustomobject]@{ Module='51-tmux.sh';        Type='skip';    Label='tmux';                                  Reason='use os painéis do Windows Terminal' }
    [pscustomobject]@{ Module='60-python-uv.sh';   Type='winget';  Label='Python (via uv)';                       Ids=@('astral-sh.uv') }
  )
}

# Já instalado? (idempotência)
function Test-WingetInstalled($id) {
  & winget list --id $id -e --accept-source-agreements *> $null
  return ($LASTEXITCODE -eq 0)
}

# Retorna a versão disponível para upgrade de um pacote já instalado, ou $null se já é a mais recente.
# Faz parsing da tabela do 'winget list': Name  Id  Version  Available  Source (5 colunas = upgrade existe).
# Se o parsing falhar (saída inesperada), retorna $null sem causar regressão.
function Get-WingetAvailableVersion($id) {
  $lines = & winget list --id $id -e --accept-source-agreements 2>&1
  foreach ($line in $lines) {
    if ($line -match [regex]::Escape($id)) {
      $parts = ($line -split '\s{2,}') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
      if ($parts.Count -ge 5) { return $parts[3] }
    }
  }
  return $null
}

# Instala um pacote winget. Tenta --scope user; cai para sem escopo se necessário.
# Se já instalado e houver upgrade, pergunta antes de atualizar (sempre, mesmo com -AcceptRisk).
function Install-WingetId($id, $label) {
  if (Test-WingetInstalled $id) {
    $avail = Get-WingetAvailableVersion $id
    if ($avail) {
      if (Test-Interactive) {
        $ans = Read-Host "$label — versao $avail disponivel. Deseja atualizar? [s/N]"
        if ($ans -match '^(s|sim|y|yes)$') {
          Write-Step "Atualizando $label..."
          & winget upgrade --id $id -e --silent --accept-source-agreements --accept-package-agreements
          if ($LASTEXITCODE -in @(0, -1978335212, -1978335189)) { Write-Ok "$label atualizado."; return $true }
          Write-WarnMsg "Falha ao atualizar $label (codigo $LASTEXITCODE)."
          return $false
        }
      } else {
        Write-WarnMsg "$label tem versao nova ($avail) disponivel. Use 'winget upgrade --id $id' para atualizar."
      }
    }
    Write-Ok "$label ja instalado."
    return $true
  }
  Write-Step "Instalando $label ($id)..."
  & winget install --id $id -e --silent --accept-source-agreements --accept-package-agreements --scope user
  if ($LASTEXITCODE -eq 0) { Write-Ok "$label instalado."; return $true }
  # -1978335189 = PACKAGE_ALREADY_INSTALLED; -1978335212 = NO_APPLICABLE_UPDATE (já na versão mais recente)
  if ($LASTEXITCODE -in @(-1978335189, -1978335212)) { Write-Ok "$label ja instalado."; return $true }
  # Alguns pacotes só têm escopo de máquina — tenta sem --scope (pode pedir UAC).
  & winget install --id $id -e --silent --accept-source-agreements --accept-package-agreements
  if ($LASTEXITCODE -eq 0) { Write-Ok "$label instalado."; return $true }
  if ($LASTEXITCODE -in @(-1978335189, -1978335212)) { Write-Ok "$label ja instalado."; return $true }
  Write-WarnMsg "Falha ao instalar $label (winget codigo $LASTEXITCODE)."
  return $false
}

# Instala o Claude Code pelo instalador oficial (auto-atualizável). Fallback: winget.
function Install-ClaudeCode {
  if (Get-Command claude -ErrorAction SilentlyContinue) { Write-Ok 'Claude Code já instalado.'; return $true }
  Write-Step 'Instalando o Claude Code (instalador oficial, auto-atualizável)...'
  # IMPORTANTE: o instalador oficial chama 'exit' em vários erros. Rodá-lo inline (no mesmo
  # processo) derrubaria esta janela e o try/catch não pega 'exit'. Por isso rodamos num
  # PROCESSO FILHO: o 'exit' morre lá, esta sessão sobrevive e o fallback winget funciona.
  $tmp = Join-Path $env:TEMP 'claude-install.ps1'
  $ran = $false
  try {
    Invoke-RestMethod -Uri $ClaudeInstallUrl -OutFile $tmp
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tmp
    $ran = ($LASTEXITCODE -eq 0)
  } catch {
    Write-WarnMsg "Instalador oficial falhou ($($_.Exception.Message))."
  } finally {
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
  }
  if (-not $ran) {
    Write-WarnMsg 'Tentando via winget...'
    return (Install-WingetId 'Anthropic.ClaudeCode' 'Claude Code')
  }
  if (Get-Command claude -ErrorAction SilentlyContinue) { Write-Ok 'Claude Code instalado.'; return $true }
  Write-Ok 'Claude Code instalado — reabra o terminal para o comando entrar no PATH.'
  return $true
}

# Instala a extensão do VS Code, se o comando 'code' já estiver no PATH desta sessão.
function Install-VscodeExt($ext) {
  if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
    Write-WarnMsg "VS Code recém-instalado: reabra o terminal e rode 'code --install-extension $ext'."
    return
  }
  & code --install-extension $ext --force | Out-Null
  if ($LASTEXITCODE -eq 0) { Write-Ok "Extensão $ext instalada." } else { Write-WarnMsg "Falha ao instalar a extensão $ext." }
}

# Caminho do perfil do PowerShell 7 (honra redirecionamento do OneDrive).
function Get-Pwsh7Profile {
  $docs = [Environment]::GetFolderPath('MyDocuments')
  return (Join-Path $docs 'PowerShell\Microsoft.PowerShell_profile.ps1')
}

# Acrescenta linhas ao perfil só se ainda não existirem (idempotente, como add_line_once).
function Add-ProfileLines($lines) {
  if (-not $lines) { return }
  $p = Get-Pwsh7Profile
  $dir = Split-Path $p
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  if (-not (Test-Path $p))   { New-Item -ItemType File -Path $p -Force | Out-Null }
  $existing = Get-Content -LiteralPath $p -Raw -ErrorAction SilentlyContinue
  if ($null -eq $existing) { $existing = '' }
  foreach ($line in $lines) {
    if ($existing -notlike "*$line*") {
      Add-Content -LiteralPath $p -Value $line
      $existing += "`n$line"
      Write-Ok "Perfil atualizado: $line"
    }
  }
}

# Aplica uma entrada do mapa. Retorna 'ok' | 'fail' | 'skip'.
function Invoke-MapEntry($entry, $activeTier) {
  if ($entry.SkipInTiers -and $activeTier -and ($entry.SkipInTiers -contains $activeTier)) {
    Write-Host "  - pulando $($entry.Label) (não incluso no tier $activeTier)" -ForegroundColor DarkGray
    return 'skip'
  }
  switch ($entry.Type) {
    'skip'    { Write-Host "  - pulando $($entry.Label): $($entry.Reason)" -ForegroundColor DarkGray; return 'skip' }
    'claude'  { if (Install-ClaudeCode) { return 'ok' } else { return 'fail' } }
    'profile' { Add-ProfileLines $entry.Profile; Write-Ok "$($entry.Label) configurado."; return 'ok' }
    default {
      $allok = $true
      foreach ($id in $entry.Ids) { if (-not (Install-WingetId $id $entry.Label)) { $allok = $false } }
      if ($entry.Profile)   { Add-ProfileLines $entry.Profile }
      if ($entry.VscodeExt) { Install-VscodeExt $entry.VscodeExt }
      if ($allok) { return 'ok' } else { return 'fail' }
    }
  }
}

# Baixa um preset do GitHub raw e devolve a lista de módulos (ignora # e vazias).
function Get-PresetModules($preset) {
  $u = "https://raw.githubusercontent.com/$Repo/$Ref/presets/$preset.txt"
  try { $raw = Invoke-RestMethod -Uri $u } catch {
    Write-ErrMsg "Não consegui baixar o preset '$preset' ($u)."; Stop-Encha 1
  }
  return ($raw -split "`n") | ForEach-Object { $_.Trim() } | Where-Object { $_ -and ($_ -notlike '#*') }
}

# Seleção personalizada (item a item). Default = conjunto do Recomendado.
function Select-Custom {
  $map = @(Get-WingetMap | Where-Object { $_.Type -ne 'skip' })
  $rec = Get-PresetModules 'recomendado'
  Write-Host ''
  Write-Host 'Itens disponíveis (números separados por espaço; Enter = Recomendado):' -ForegroundColor White
  for ($i = 0; $i -lt $map.Count; $i++) {
    $mark = if ($rec -contains $map[$i].Module) { '*' } else { ' ' }
    Write-Host ("  [{0}] {1,2}) {2}" -f $mark, ($i + 1), $map[$i].Label)
  }
  $inp = Read-Host 'Seleção'
  if (-not $inp) { return @{ Tier=''; Modules=$rec } }
  $chosen = @()
  foreach ($tok in ($inp -split '\s+')) {
    if ($tok -match '^\d+$') {
      $idx = [int]$tok - 1
      if ($idx -ge 0 -and $idx -lt $map.Count) { $chosen += $map[$idx].Module }
    }
  }
  return @{ Tier=''; Modules=$chosen }
}

# Decide o conjunto: por -Preset ou pelo menu interativo.
function Resolve-Selection {
  if ($Preset) { return @{ Tier=$Preset; Modules=(Get-PresetModules $Preset) } }
  if (-not (Test-Interactive)) {
    Write-WarnMsg 'Sem terminal interativo: usando o tier "recomendado". Para escolher, passe -Preset.'
    return @{ Tier='recomendado'; Modules=(Get-PresetModules 'recomendado') }
  }
  Write-Host ''
  Write-Host 'Escolha um tier:' -ForegroundColor White
  Write-Host '  1) Rapido      - so o essencial p/ rodar o Claude Code'
  Write-Host '  2) Recomendado - essencial + shell + git/IDE'
  Write-Host '  3) Completo    - recomendado + Docker, Python'
  Write-Host '  4) Personalizado'
  Write-Host '  0) Cancelar'
  $c = Read-Host 'Opcao [2]'
  if (-not $c) { $c = '2' }
  switch ($c) {
    '1' { return @{ Tier='rapido';      Modules=(Get-PresetModules 'rapido') } }
    '2' { return @{ Tier='recomendado'; Modules=(Get-PresetModules 'recomendado') } }
    '3' { return @{ Tier='completo';    Modules=(Get-PresetModules 'completo') } }
    '4' { return (Select-Custom) }
    '0' { Write-Host 'Cancelado.'; return @{ Cancel=$true } }
    default { Write-WarnMsg "Opção inválida: $c"; Stop-Encha 1 }
  }
}

# Orquestra a instalação nativa.
function Invoke-NativeInstall {
  Confirm-Risk
  if (-not (Test-Winget)) { Stop-Encha 1 }

  $anyFail = $false
  do {
    $sel = Resolve-Selection
    if ($sel.Cancel) { break }

    $modules = @($sel.Modules)
    if ($modules.Count -eq 0) { Write-WarnMsg 'Nada selecionado.'; break }

    $okN = 0; $failN = 0; $skipN = 0; $failed = @()
    foreach ($entry in (Get-WingetMap)) {
      if ($modules -contains $entry.Module) {
        switch (Invoke-MapEntry $entry $sel.Tier) {
          'ok'   { $okN++ }
          'fail' { $failN++; $failed += $entry.Label }
          'skip' { $skipN++ }
        }
      }
    }
    if ($failN -gt 0) { $anyFail = $true }

    Write-Host ''
    Write-Step 'Resumo'
    Write-Ok "Concluidos: $okN"
    if ($skipN -gt 0) { Write-Host "  Pulados: $skipN" -ForegroundColor DarkGray }
    if ($failN -gt 0) {
      Write-WarnMsg "Com falha: $failN"
      $failed | ForEach-Object { Write-Host "   - $_" -ForegroundColor Yellow }
    }
    Write-Host ''
    Write-Ok 'Pronto! Abra um PowerShell NOVO e rode: claude'

    if (-not (Test-Interactive)) { break }
    $again = Read-Host 'Voltar ao menu principal? [s/N]'
    if ($again -notmatch '^(s|sim|y|yes)$') { break }
    Write-Host ''
  } while ($true)

  if ($anyFail) { Stop-Encha 1 } else { Stop-Encha 0 }
}

# ============================ TRILHA WSL (avançado) ============================

# Reexecuta o script como administrador, se necessário (só no modo WSL).
function Invoke-Elevation {
  if (Test-Admin) { return }
  if (-not $PSCommandPath) {
    Write-ErrMsg 'Este passo precisa de administrador.'
    Write-Host   'Feche este PowerShell e reabra-o COMO ADMINISTRADOR' -ForegroundColor White
    Write-Host   '(menu Iniciar > digite "PowerShell" > botão direito > "Executar como administrador"),' -ForegroundColor White
    Write-Host   'e rode A MESMA linha de comando novamente.' -ForegroundColor White
    Stop-Encha 1
  }
  Write-WarnMsg 'Este passo precisa de privilégios de administrador. Solicitando elevação...'
  $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Mode', 'wsl', '-Distro', $Distro)
  if ($Preset)          { $argList += @('-Preset', $Preset) }
  if ($AllowUnverified) { $argList += '-AllowUnverified' }
  # O aviso já foi aceito antes da elevação — não pergunta de novo na janela elevada.
  $argList += '-AcceptRisk'
  try {
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList
  } catch {
    Write-ErrMsg "Não foi possível elevar: $($_.Exception.Message)"; Stop-Encha 1
  }
  Stop-Encha 0
}

function Test-WslPresent { return [bool](Get-Command wsl.exe -ErrorAction SilentlyContinue) }
function Get-WindowsBuild { return [int][System.Environment]::OSVersion.Version.Build }

# Lista distros instaladas (nomes "limpos"). Tolera UTF-16 residual e linhas vazias.
function Get-WslDistros {
  if (-not (Test-WslPresent)) { return @() }
  $raw = & wsl.exe --list --quiet 2>$null
  if ($LASTEXITCODE -ne 0 -or -not $raw) { return @() }
  return $raw |
    ForEach-Object { ($_ -replace "`0", '').Trim() } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
}

# Match tolerante: 'Ubuntu' casa com 'Ubuntu', 'Ubuntu-22.04', 'Ubuntu 24.04 LTS'.
function Test-DistroInstalled($name) {
  foreach ($d in (Get-WslDistros)) {
    if (($d -ieq $name) -or ($d -like "$name*")) { return $true }
  }
  return $false
}

function Set-WslDefaultV2 {
  & wsl.exe --set-default-version 2 | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Write-WarnMsg 'Não consegui definir o WSL2 como padrão (talvez falte a atualização do kernel).'
    Write-Host    'Se a distro ficar em WSL1, instale o kernel: https://aka.ms/wsl2kernel' -ForegroundColor White
  }
}

function Step-InstallWsl {
  Write-Step "Verificando o WSL2 e a distro '$Distro'..."
  if (Test-DistroInstalled $Distro) {
    Write-Ok "Distro compatível com '$Distro' já instalada."
    Set-WslDefaultV2
    return $true
  }
  $build = Get-WindowsBuild
  if ($build -lt 19041) {
    Write-ErrMsg "Seu Windows (build $build) não suporta 'wsl --install' (requer 2004+ / build 19041)."
    Write-Host    'Atualize o Windows ou instale o WSL manualmente: https://learn.microsoft.com/windows/wsl/install' -ForegroundColor White
    return $false
  }
  if (-not (Test-WslPresent)) {
    Write-ErrMsg 'wsl.exe não encontrado. Atualize o Windows e tente novamente.'
    return $false
  }

  Invoke-Elevation  # daqui em diante precisamos de admin

  Write-Step "Instalando o WSL2 + $Distro (pode demorar e baixar bastante)..."
  & wsl.exe --install -d $Distro
  $installCode = $LASTEXITCODE
  Set-WslDefaultV2

  if (($installCode -eq 0) -and (Test-DistroInstalled $Distro)) {
    Write-Ok "WSL/$Distro instalado."
    return $true
  }
  if ($installCode -ne 0) {
    Write-WarnMsg "O 'wsl --install' retornou código $installCode."
  }
  Write-WarnMsg 'A instalação do WSL provavelmente exige um REINÍCIO do Windows.'
  Write-Host    'Depois de reiniciar:' -ForegroundColor White
  Write-Host    "  1) Abra o app '$Distro' uma vez e crie seu usuário e senha do Linux." -ForegroundColor White
  Write-Host    '  2) Rode esta mesma linha de comando novamente.' -ForegroundColor White
  return $false
}

# Garante um usuário não-root (o Homebrew se recusa a rodar como root).
function Test-NonRootUser {
  $who = & wsl.exe -d $Distro -- bash -lc 'whoami' 2>$null
  if ($LASTEXITCODE -ne 0) { return $false }
  if ($who) { $who = ($who -replace "`0", '').Trim() }
  return ($who -and ($who -ne 'root'))
}

# Roda o instalador bash dentro do WSL.
function Step-RunInstaller {
  Write-Step "Executando o instalador dentro do WSL ($Distro)..."
  & wsl.exe -d $Distro --user root -- bash -lc 'command -v curl >/dev/null 2>&1 || (apt-get update -y && apt-get install -y curl)'
  if ($LASTEXITCODE -ne 0) {
    Write-WarnMsg 'Não consegui garantir o curl no Ubuntu (seguindo mesmo assim).'
  }
  $envPrefix = 'ENCHA_ACCEPT_RISK=1 '
  if ($AllowUnverified) { $envPrefix += 'ENCHA_ALLOW_UNVERIFIED=1 ' }
  $bashArgs = ''
  if ($Preset) { $bashArgs = " -- --preset $Preset" }
  $cmd = "curl -fsSL '$Url' | ${envPrefix}bash -s$bashArgs"
  & wsl.exe -d $Distro -- bash -lc $cmd
  $code = $LASTEXITCODE
  if ($code -eq 0) {
    Write-Ok 'Instalação concluída dentro do WSL.'
    return $true
  }
  Write-ErrMsg "O instalador retornou código $code. Veja as mensagens acima."
  return $false
}

function Invoke-WslInstall {
  Confirm-Risk -Wsl
  if (-not (Step-InstallWsl)) {
    Write-WarnMsg 'Etapa do WSL ainda não concluída. Reinicie/abra o Ubuntu conforme indicado e rode novamente.'
    Stop-Encha 1
  }
  if (-not (Test-NonRootUser)) {
    Write-WarnMsg "Não consegui rodar comandos no '$Distro' como usuário comum."
    Write-Host    'Possíveis causas e solução:' -ForegroundColor White
    Write-Host    "  - Se você acabou de instalar o WSL, talvez precise REINICIAR o Windows." -ForegroundColor White
    Write-Host    "  - Abra o app '$Distro' uma vez e crie seu usuário e senha do Linux." -ForegroundColor White
    Write-Host    '  Depois, rode esta mesma linha de comando novamente.' -ForegroundColor White
    Stop-Encha 1
  }
  if (Step-RunInstaller) {
    Write-Host ''
    Write-Ok "Tudo pronto! Abra o '$Distro' (ou o Windows Terminal) e comece com: claude"
    Stop-Encha 0
  } else {
    Stop-Encha 1
  }
}

# ----------------------------- Fluxo principal -----------------------------
try {
  Assert-Inputs

  Write-Host ''
  Write-Host '  Encha Vibe Pack - instalador para Windows' -ForegroundColor Cyan
  Write-Host "  repo: $Repo  -  ref: $Ref  -  modo: $Mode" -ForegroundColor DarkGray

  if ($Mode -eq 'wsl') {
    Invoke-WslInstall
  } else {
    Invoke-NativeInstall
  }
} catch {
  if ($_.Exception.Message -ne 'ENCHA_STOP') {
    Write-ErrMsg "Erro inesperado: $($_.Exception.Message)"
    $script:EnchaExitCode = 1
  }
}
# Em CI/pipe (sem console interativo) propaga o código de saída; em sessão interativa
# NÃO chamamos 'exit' — isso fecharia a janela do usuário quando rodado in-process.
if (-not (Test-Interactive)) { exit $script:EnchaExitCode }
