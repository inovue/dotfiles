#Requires -Version 5.1
# Install / refresh Windows-side agent-browser for the WSL bridge.
$ErrorActionPreference = "Stop"

function Add-UserPath([string]$dir) {
  if (-not $dir -or -not (Test-Path $dir)) { return }
  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
  if (-not $userPath) { $userPath = "" }
  $parts = @($userPath -split ";" | Where-Object { $_ -and $_.Trim() -ne "" })
  if ($parts -notcontains $dir) {
    [Environment]::SetEnvironmentVariable("Path", (($parts + $dir) -join ";"), "User")
  }
  if ($env:Path -notlike "*$dir*") {
    $env:Path = "$dir;$env:Path"
  }
}

Add-UserPath (Join-Path $env:USERPROFILE ".local\bin")
Add-UserPath (Join-Path $env:APPDATA "fnm\aliases\default")
Add-UserPath (Join-Path $env:APPDATA "npm")

$npm = Get-Command npm -ErrorAction SilentlyContinue
if (-not $npm) {
  Write-Output "npm not found on Windows; trying winget Node.js LTS..."
  $winget = Get-Command winget -ErrorAction SilentlyContinue
  if (-not $winget) {
    throw "npm not found and winget unavailable. Install Node.js for Windows, then re-run setup."
  }
  & winget install -e --id OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements
  $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
    [Environment]::GetEnvironmentVariable("Path", "User")
  $npm = Get-Command npm -ErrorAction SilentlyContinue
  if (-not $npm) {
    throw "npm still not found after winget Node install. Open a new terminal and re-run setup."
  }
}

Write-Output ("npm: " + $npm.Source)
npm install -g agent-browser
$ab = Get-Command agent-browser -ErrorAction SilentlyContinue
if (-not $ab) {
  throw "agent-browser not on PATH after npm install -g"
}
Write-Output ("agent-browser: " + ((& agent-browser --version) -join " "))
