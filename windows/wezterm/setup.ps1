#Requires -Version 5.1
# Sync wezterm.lua and ensure WezTerm nightly via winget.
$ErrorActionPreference = 'Stop'

$RepoLua = Join-Path $PSScriptRoot 'wezterm.lua'
$Dest = Join-Path $env:USERPROFILE '.wezterm.lua'
Copy-Item -LiteralPath $RepoLua -Destination $Dest -Force
Write-Host "==> Synced $Dest"

Write-Host '==> winget install wez.wezterm.nightly'
winget install --id wez.wezterm.nightly -e `
  --accept-package-agreements --accept-source-agreements `
  --disable-interactivity --silent
$wingetCode = $LASTEXITCODE

function Get-WezTermExe {
  $cmd = Get-Command wezterm.exe -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $p = Join-Path $env:ProgramFiles 'WezTerm\wezterm.exe'
  if (Test-Path -LiteralPath $p) { return $p }
  return $null
}

$exe = Get-WezTermExe
if (-not $exe) {
  Write-Host @'
wezterm.exe not found. If winget complained about installer hash, run once as admin:

  winget settings --enable InstallerHashOverride

Then re-run this script.
'@
  exit 1
}

$ver = & $exe --version
Write-Host "==> $ver"
if ("$ver" -match '20240203') {
  Write-Host 'Still on 20240203 stable. Install nightly failed (winget exit '"$wingetCode"').'
  Write-Host 'Admin once: winget settings --enable InstallerHashOverride'
  exit 1
}

Write-Host '==> Fully quit and reopen WezTerm.'
