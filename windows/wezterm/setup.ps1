#Requires -Version 5.1
# Sync wezterm.lua, install UDEV Gothic 35NFLG, ensure WezTerm nightly via winget.
$ErrorActionPreference = 'Stop'

$RepoLua = Join-Path $PSScriptRoot 'wezterm.lua'
$Dest = Join-Path $env:USERPROFILE '.wezterm.lua'
Copy-Item -LiteralPath $RepoLua -Destination $Dest -Force
Write-Host "==> Synced $Dest"

function Test-UdevGothic35NflgInstalled {
  $fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
  $marker = Join-Path $fontDir 'UDEVGothic35NFLG-Regular.ttf'
  return (Test-Path -LiteralPath $marker)
}

function Install-UdevGothic35Nflg {
  if (Test-UdevGothic35NflgInstalled) {
    Write-Host '==> UDEV Gothic 35NFLG already installed (skip)'
    return
  }

  Write-Host '==> Install UDEV Gothic 35NFLG (GitHub yuru7/udev-gothic)'
  $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/yuru7/udev-gothic/releases/latest'
  $asset = $release.assets | Where-Object { $_.name -like 'UDEVGothic_NF_*.zip' } | Select-Object -First 1
  if (-not $asset) {
    throw 'UDEVGothic_NF_*.zip not found in latest GitHub release'
  }

  $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("udev-gothic-35nflg-" + [guid]::NewGuid().ToString())
  New-Item -ItemType Directory -Path $tmp | Out-Null
  try {
    $zip = Join-Path $tmp $asset.name
    Write-Host ("    downloading " + $asset.name)
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip
    Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force

    $fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    New-Item -ItemType Directory -Path $fontDir -Force | Out-Null
    $regKey = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'

    $fonts = Get-ChildItem -Path $tmp -Recurse -File -Filter 'UDEVGothic35NFLG-*.ttf'
    if (-not $fonts) {
      throw 'No UDEVGothic35NFLG-*.ttf found in zip'
    }

    foreach ($font in $fonts) {
      $destFont = Join-Path $fontDir $font.Name
      Copy-Item -LiteralPath $font.FullName -Destination $destFont -Force
      $propName = $font.BaseName + ' (TrueType)'
      New-ItemProperty -Path $regKey -Name $propName -Value $destFont -PropertyType String -Force | Out-Null
      Write-Host ("    installed " + $font.Name)
    }
  }
  finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
  }
}

function Get-WezTermExe {
  $cmd = Get-Command wezterm.exe -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $p = Join-Path $env:ProgramFiles 'WezTerm\wezterm.exe'
  if (Test-Path -LiteralPath $p) { return $p }
  return $null
}

function Test-WezTermOk {
  $exe = Get-WezTermExe
  if (-not $exe) { return $false }
  $ver = & $exe --version 2>$null
  if (-not $ver) { return $false }
  # 20240203 stable is too old for Kitty graphics on Windows
  return ("$ver" -notmatch '20240203')
}

Install-UdevGothic35Nflg

if (Test-WezTermOk) {
  Write-Host ("==> WezTerm ok: " + (& (Get-WezTermExe) --version))
  Write-Host '==> Fully quit and reopen WezTerm if config just changed.'
  exit 0
}

# Nightly vanity URL drifts from the winget manifest hash → always ignore hash.
# Requires one-time admin: winget settings --enable InstallerHashOverride
Write-Host '==> winget install wez.wezterm.nightly'
$wingetOut = & winget install --id wez.wezterm.nightly -e `
  --accept-package-agreements --accept-source-agreements `
  --disable-interactivity --silent `
  --ignore-security-hash 2>&1 | Out-String
Write-Host $wingetOut
$wingetCode = [int]$LASTEXITCODE

$exe = Get-WezTermExe
if (-not $exe -or -not (Test-WezTermOk)) {
  Write-Host @"
winget nightly failed (exit $wingetCode). Nightly hash drifts often.

Admin PowerShell once:
  winget settings --enable InstallerHashOverride

Then re-run (non-admin):
  ./windows/wezterm/setup.sh
"@
  exit 1
}

Write-Host ("==> " + (& $exe --version))
Write-Host '==> Fully quit and reopen WezTerm.'
