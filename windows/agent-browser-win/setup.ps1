#Requires -Version 5.1
# Install / refresh Windows-side agent-browser for the WSL bridge.
$ErrorActionPreference = "Stop"

# WSL-launched powershell.exe inherits UNC cwd (\\wsl.localhost\...), which
# breaks npm.cmd / cmd.exe. Move to a Windows-local path first.
Set-Location $env:USERPROFILE

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
# Some npm builds gate postinstall via allow-scripts; enable when the flag exists.
$installArgs = @("install", "-g", "agent-browser")
$installHelp = (& npm install --help 2>&1 | Out-String)
if ($installHelp -match "allow-scripts") {
  $installArgs += "--allow-scripts=agent-browser"
  Write-Output "npm supports --allow-scripts; enabling for agent-browser"
}
& npm @installArgs
if ($LASTEXITCODE -ne 0) {
  throw "npm install -g agent-browser failed"
}
$ab = Get-Command agent-browser -ErrorAction SilentlyContinue
if (-not $ab) {
  throw "agent-browser not on PATH after npm install -g"
}
Write-Output ("agent-browser: " + ((& agent-browser --version) -join " "))
