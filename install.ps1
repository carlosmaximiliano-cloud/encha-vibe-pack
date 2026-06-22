#Requires -Version 5.1
<#
.SYNOPSIS
  Bootstrap do Encha Vibe Pack no Windows: prepara o WSL2 + Ubuntu e roda o
  instalador (bash) lá dentro.

.DESCRIPTION
  Para iniciantes no Windows, o melhor ambiente para o Claude Code é o WSL2.
  Este script é RE-ENTRANTE: rode, reinicie quando pedido, e rode de novo — ele
  descobre sozinho em que etapa está:
    1) Habilita o WSL2 e instala o Ubuntu (pode exigir reinício).
    2) Garante que exista um usuário Linux (não-root) no Ubuntu.
    3) Executa o instalador bash dentro do WSL.

  TESTE MANUAL (não há como testar Windows fora de uma máquina Windows):
    - Win10 build < 19041: deve recusar com mensagem clara (sem 'wsl --install').
    - 1ª instalação: instala WSL+Ubuntu, pede reboot, e ao reabrir o Ubuntu cria o usuário.
    - 2ª execução: detecta a distro, detecta usuário não-root, e roda o instalador.

.PARAMETER Preset
  Preset a instalar sem menu: rapido | recomendado | completo. Vazio = menu interativo.

.PARAMETER Distro
  Distribuição WSL a usar/instalar (padrão: Ubuntu).

.EXAMPLE
  # No PowerShell aberto COMO ADMINISTRADOR:
  irm https://raw.githubusercontent.com/<user>/encha-vibe-pack/<tag>/install.ps1 | iex
#>
[CmdletBinding()]
param(
  [ValidateSet('', 'rapido', 'recomendado', 'completo')]
  [string]$Preset = '',
  [string]$Distro = 'Ubuntu',
  [switch]$AllowUnverified,
  [switch]$AcceptRisk
)

$ErrorActionPreference = 'Stop'
# Faz o wsl.exe emitir UTF-8 (em vez de UTF-16LE), evitando lixo no parsing.
$env:WSL_UTF8 = '1'

# --- Configuração do release (mesma do install.sh) ---
$Repo = $env:ENCHA_REPO; if (-not $Repo) { $Repo = 'carlosmaximiliano-cloud/encha-vibe-pack' }
$Ref  = $env:ENCHA_REF;  if (-not $Ref)  { $Ref  = 'v0.1.0' }
$Url  = "https://raw.githubusercontent.com/$Repo/$Ref/install.sh"

# --- Saída amigável ---
function Write-Step($msg)    { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)      { Write-Host "[ok] $msg"  -ForegroundColor Green }
function Write-WarnMsg($msg) { Write-Host "[!] $msg"   -ForegroundColor Yellow }
function Write-ErrMsg($msg)  { Write-Host "[x] $msg"   -ForegroundColor Red }

# --- Validação de entradas (defesa em profundidade; valores podem vir de env) ---
function Assert-Inputs {
  if ($Repo -notmatch '^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$') {
    Write-ErrMsg "ENCHA_REPO inválido: '$Repo' (esperado: owner/repo)."; exit 1
  }
  if ($Ref -notmatch '^[A-Za-z0-9._-]+$') {
    Write-ErrMsg "ENCHA_REF inválido: '$Ref'."; exit 1
  }
  if ($Distro -notmatch '^[A-Za-z0-9 ._-]+$') {
    Write-ErrMsg "Distro inválida: '$Distro'."; exit 1
  }
  if (($Ref -in @('main','master','HEAD','develop','dev','latest')) -and (-not $AllowUnverified)) {
    Write-ErrMsg "ENCHA_REF aponta para uma branch ('$Ref'). Use uma tag (ex.: v0.1.0) ou passe -AllowUnverified."
    exit 1
  }
}

# --- Aviso de isenção de responsabilidade ---
function Show-Disclaimer {
  Write-Host ''
  Write-Host '  +-------------------------------------------------------------+' -ForegroundColor Yellow
  Write-Host '  |  !   AVISO -- leia antes de prosseguir                      |' -ForegroundColor Yellow
  Write-Host '  +-------------------------------------------------------------+' -ForegroundColor Yellow
  Write-Host '  |                                                             |' -ForegroundColor Yellow
  Write-Host '  |  Este instalador e ' -ForegroundColor Yellow -NoNewline
  Write-Host 'GRATUITO' -ForegroundColor White -NoNewline
  Write-Host ', esta em ' -ForegroundColor Yellow -NoNewline
  Write-Host 'VERSAO BETA' -ForegroundColor White -NoNewline
  Write-Host ' e e        |' -ForegroundColor Yellow
  Write-Host '  |  fornecido ' -ForegroundColor Yellow -NoNewline
  Write-Host 'SEM QUALQUER GARANTIA' -ForegroundColor White -NoNewline
  Write-Host ' (licenca MIT).          |' -ForegroundColor Yellow
  Write-Host '  |                                                             |' -ForegroundColor Yellow
  Write-Host '  |  O que ele faz na sua maquina:                             |' -ForegroundColor Yellow
  Write-Host '  |  * Habilita o WSL2 e instala o Ubuntu (pode reiniciar)     |' -ForegroundColor Yellow
  Write-Host '  |  * Instala pacotes e edita configs de shell no Linux        |' -ForegroundColor Yellow
  Write-Host '  |                                                             |' -ForegroundColor Yellow
  Write-Host '  |  Ao prosseguir, voce assume os riscos pelo uso.            |' -ForegroundColor Yellow
  Write-Host '  |                                                             |' -ForegroundColor Yellow
  Write-Host '  +-------------------------------------------------------------+' -ForegroundColor Yellow
  Write-Host ''
}

# Garante o aceite do aviso. Aceita via -AcceptRisk, env ENCHA_ACCEPT_RISK=1,
# -Preset (análogo ao --yes) ou resposta interativa (default = Não).
function Confirm-Risk {
  Show-Disclaimer
  if ($AcceptRisk -or ($env:ENCHA_ACCEPT_RISK -eq '1') -or $Preset) { return }
  $ans = Read-Host 'Voce concorda em prosseguir, por sua conta e risco? [s/N]'
  if ($ans -notmatch '^(s|sim|y|yes)$') {
    Write-ErrMsg 'E preciso aceitar os termos para continuar.'
    Write-Host   'Para automatizar, defina $env:ENCHA_ACCEPT_RISK=1 ou passe -AcceptRisk.' -ForegroundColor White
    exit 1
  }
}

function Test-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p  = New-Object Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

# Reexecuta o script como administrador, se necessário.
function Invoke-Elevation {
  if (Test-Admin) { return }
  # Rodando via `irm | iex` não há arquivo para re-executar elevado.
  if (-not $PSCommandPath) {
    Write-ErrMsg 'Este passo precisa de administrador.'
    Write-Host   'Feche este PowerShell e reabra-o COMO ADMINISTRADOR' -ForegroundColor White
    Write-Host   '(menu Iniciar > digite "PowerShell" > clique com o botão direito > "Executar como administrador"),' -ForegroundColor White
    Write-Host   'e rode A MESMA linha de comando novamente.' -ForegroundColor White
    exit 1
  }
  Write-WarnMsg 'Este passo precisa de privilégios de administrador. Solicitando elevação...'
  $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Distro', $Distro)
  if ($Preset)          { $argList += @('-Preset', $Preset) }
  if ($AllowUnverified) { $argList += '-AllowUnverified' }
  # O aviso já foi aceito antes da elevação — não pergunta de novo na janela elevada.
  $argList += '-AcceptRisk'
  try {
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList
  } catch {
    Write-ErrMsg "Não foi possível elevar: $($_.Exception.Message)"; exit 1
  }
  exit 0
}

function Test-WslPresent {
  return [bool](Get-Command wsl.exe -ErrorAction SilentlyContinue)
}

function Get-WindowsBuild {
  return [int][System.Environment]::OSVersion.Version.Build
}

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

# Define o WSL2 como padrão; avisa (sem abortar) se faltar o kernel.
function Set-WslDefaultV2 {
  & wsl.exe --set-default-version 2 | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Write-WarnMsg 'Não consegui definir o WSL2 como padrão (talvez falte a atualização do kernel).'
    Write-Host    'Se a distro ficar em WSL1, instale o kernel: https://aka.ms/wsl2kernel' -ForegroundColor White
  }
}

# Etapa 1 — habilitar WSL2 + instalar a distro. Retorna $true se a distro está registrada.
function Step-InstallWsl {
  Write-Step "Verificando o WSL2 e a distro '$Distro'..."

  if (Test-DistroInstalled $Distro) {
    Write-Ok "Distro compatível com '$Distro' já instalada."
    Set-WslDefaultV2
    return $true
  }

  # Para instalar, precisamos de Windows compatível e do wsl.exe.
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

# Etapa 2 — garante um usuário não-root (o Homebrew se recusa a rodar como root).
# Retorna $true só se a distro roda E o usuário padrão não é root.
function Test-NonRootUser {
  $who = & wsl.exe -d $Distro -- bash -lc 'whoami' 2>$null
  if ($LASTEXITCODE -ne 0) { return $false }   # distro não inicializou (talvez falte reboot/1º boot)
  if ($who) { $who = ($who -replace "`0", '').Trim() }
  return ($who -and ($who -ne 'root'))
}

# Etapa 3 — roda o instalador bash dentro do WSL.
function Step-RunInstaller {
  Write-Step "Executando o instalador dentro do WSL ($Distro)..."

  # Garante o curl como ROOT (sem sudo → sem prompt de senha sem TTY).
  & wsl.exe -d $Distro --user root -- bash -lc 'command -v curl >/dev/null 2>&1 || (apt-get update -y && apt-get install -y curl)'
  if ($LASTEXITCODE -ne 0) {
    Write-WarnMsg 'Não consegui garantir o curl no Ubuntu (seguindo mesmo assim).'
  }

  # O aviso já foi aceito do lado do Windows — propaga para o run.sh não repetir.
  $envPrefix = 'ENCHA_ACCEPT_RISK=1 '
  if ($AllowUnverified) { $envPrefix += 'ENCHA_ALLOW_UNVERIFIED=1 ' }
  $bashArgs = ''
  if ($Preset) { $bashArgs = " -- --preset $Preset" }

  # Roda como o usuário padrão (não-root). A URL vai entre aspas simples no bash.
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

# ----------------------------- Fluxo principal -----------------------------
Assert-Inputs

Write-Host ''
Write-Host '  Encha Vibe Pack — bootstrap para Windows (via WSL2)' -ForegroundColor Cyan
Write-Host "  repo: $Repo  -  ref: $Ref" -ForegroundColor DarkGray

Confirm-Risk

if (-not (Step-InstallWsl)) {
  Write-WarnMsg 'Etapa do WSL ainda não concluída. Reinicie/abra o Ubuntu conforme indicado e rode novamente.'
  exit 1
}

if (-not (Test-NonRootUser)) {
  Write-WarnMsg "Não consegui rodar comandos no '$Distro' como usuário comum."
  Write-Host    'Possíveis causas e solução:' -ForegroundColor White
  Write-Host    "  - Se você acabou de instalar o WSL, talvez precise REINICIAR o Windows." -ForegroundColor White
  Write-Host    "  - Abra o app '$Distro' uma vez e crie seu usuário e senha do Linux." -ForegroundColor White
  Write-Host    '  Depois, rode esta mesma linha de comando novamente.' -ForegroundColor White
  exit 1
}

if (Step-RunInstaller) {
  Write-Host ''
  Write-Ok "Tudo pronto! Abra o '$Distro' (ou o Windows Terminal) e comece com: claude"
  exit 0
} else {
  exit 1
}
