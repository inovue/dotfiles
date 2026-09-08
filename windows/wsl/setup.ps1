#Requires -Version 5.1
# Write %USERPROFILE%\.wslconfig sized for terminal-browser + Cursor agents.
$ErrorActionPreference = 'Stop'

$Dest = Join-Path $env:USERPROFILE '.wslconfig'

$cs = Get-CimInstance Win32_ComputerSystem
$hostGB = [math]::Floor([double]$cs.TotalPhysicalMemory / 1GB)
$logical = [int]$cs.NumberOfLogicalProcessors
if ($logical -lt 1) { $logical = 4 }

# ~half of host RAM, leave headroom for Windows GUI; clamp by host size.
$half = [math]::Floor($hostGB / 2)
if ($hostGB -ge 16) {
  $wslMemGB = [math]::Min(12, [math]::Max(8, $half))
} elseif ($hostGB -ge 12) {
  $wslMemGB = 8
} elseif ($hostGB -ge 8) {
  $wslMemGB = 6
} else {
  $wslMemGB = [math]::Max(3, $hostGB - 2)
}

# Half of logical CPUs, clamp 4-8.
$wslCpu = [math]::Min(8, [math]::Max(4, [math]::Floor($logical / 2)))

$date = Get-Date -Format 'yyyy-MM-dd'
# ASCII-only body: Windows PowerShell 5.1 Set-Content -Encoding utf8 adds BOM and mangles non-ASCII.
$lines = @(
  '# Managed by inovue/dotfiles (windows/wsl).'
  "# Applied $date. Host ~${hostGB}GB RAM / $logical logical CPUs."
  '# After change: wsl --shutdown (Windows PowerShell), then reopen WezTerm.'
  ''
  '[wsl2]'
  "memory=${wslMemGB}GB"
  "processors=$wslCpu"
  ''
)
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines($Dest, $lines, $utf8NoBom)

Write-Host "==> Wrote $Dest (memory=${wslMemGB}GB processors=$wslCpu; host ~${hostGB}GB / $logical CPUs)"
Write-Host '==> Apply: in Windows PowerShell run  wsl --shutdown  then reopen WezTerm'
