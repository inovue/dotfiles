# Open terminal-browser in a WezTerm sibling pane (not nested in herdr).
# Called from tb-split.sh with -BashLc and -Cwd.
#
# The active pane is already domain WSL:Ubuntu. Do NOT spawn wsl.exe here —
# that is a Windows binary inside a Linux domain and the pane dies immediately.
# Run `bash -lc …` so the child inherits the WSL domain.
param(
  [Parameter(Mandatory = $true)]
  [string]$BashLc,

  [int]$Percent = 40,

  [Parameter(Mandatory = $true)]
  [string]$Cwd
)

$ErrorActionPreference = "Stop"

$wezCandidates = @(
  "${env:ProgramFiles}\WezTerm\wezterm.exe",
  "${env:LOCALAPPDATA}\Programs\WezTerm\wezterm.exe"
)
$wez = $wezCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $wez) {
  throw "wezterm.exe not found"
}

# gui-sock-<pid>: only keep sockets whose WezTerm PID is still alive.
$sockDir = Join-Path $env:USERPROFILE ".local\share\wezterm"
$socks = @(Get-ChildItem -Path $sockDir -Filter "gui-sock-*" -ErrorAction SilentlyContinue |
  Where-Object {
    if ($_.BaseName -notmatch '^gui-sock-(\d+)$') { return $false }
    $null -ne (Get-Process -Id ([int]$Matches[1]) -ErrorAction SilentlyContinue)
  } |
  Sort-Object LastWriteTime -Descending)
if (-not $socks) {
  throw "no live WezTerm gui-sock in $sockDir (is WezTerm running?)"
}
$env:WEZTERM_UNIX_SOCKET = $socks[0].FullName

$raw = & $wez cli list --format json | Out-String
$panes = @($raw | ConvertFrom-Json)
if (-not $panes) {
  throw "wezterm cli list returned no panes"
}

# Prefer focused pane (usually herdr). Title matching is unreliable on WSL.
$base = $panes | Where-Object { $_.is_active } | Select-Object -First 1
if (-not $base) {
  $base = $panes[0]
}

$newId = & $wez cli split-pane `
  --pane-id $base.pane_id `
  --right `
  --percent $Percent `
  --cwd $Cwd `
  -- bash -lc $BashLc

Write-Output "split:$newId"
