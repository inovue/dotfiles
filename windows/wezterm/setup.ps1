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

    # 35 + NF + LG family (WezTerm: "UDEV Gothic 35NFLG")
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

Install-UdevGothic35Nflg

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
