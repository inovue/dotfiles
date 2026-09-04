#Requires -Version 5.1
<#
.SYNOPSIS
  WSL/Cursor から Windows Chrome（専用プロファイル）を CDP 操作するヘルパー。

.DESCRIPTION
  Chrome 136+ はデフォルト User Data で --remote-debugging-port を無視する。
  専用プロファイル (%LOCALAPPDATA%\Google\Chrome\AgentBrowserProfile) を使い、
  Windows 側 agent-browser 経由で操作する（WSL から 127.0.0.1:9222 は届かない）。

.EXAMPLE
  .\agent-browser-win.ps1 start
  .\agent-browser-win.ps1 stop
  .\agent-browser-win.ps1 status
  .\agent-browser-win.ps1 doctor
  .\agent-browser-win.ps1 run -ArgsBase64 <base64-of-json-args>
#>
param(
  [Parameter(Position = 0)]
  [ValidateSet("start", "up", "stop", "down", "status", "st", "doctor", "run")]
  [string]$Action = "status",

  [Parameter(Position = 1)]
  [string]$ArgsBase64 = "",

  # Optional overrides (preferred over relying on WSL→Windows env inheritance)
  [string]$ProfileNameOverride = "",
  [string]$CdpPortOverride = "",
  [string]$SessionOverride = ""
)

$ErrorActionPreference = "Stop"

# User-scoped PATH only (no hardcoded username paths)
$pathParts = @(
  (Join-Path $env:USERPROFILE ".local\bin"),
  (Join-Path $env:APPDATA "fnm\aliases\default"),
  (Join-Path $env:LOCALAPPDATA "fnm"),
  $env:Path
)
$env:Path = ($pathParts -join ";")

$ChromeExeCandidates = @(
  "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe",
  "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
  (Join-Path $env:LOCALAPPDATA "Google\Chrome\Application\chrome.exe")
)
$ChromeExe = $ChromeExeCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

if ($ProfileNameOverride) {
  $ProfileName = $ProfileNameOverride
} elseif ($env:AGENT_BROWSER_WIN_PROFILE) {
  $ProfileName = $env:AGENT_BROWSER_WIN_PROFILE
} else {
  $ProfileName = "AgentBrowserProfile"
}

# Reject names that collide with real Chrome paths or substring-match too broadly.
$deniedProfiles = @(
  "Default", "Chrome", "User Data", "Profile", "System Profile",
  "Guest Profile", "Google", "Application"
)
if (
  [string]::IsNullOrWhiteSpace($ProfileName) -or
  $ProfileName.Length -lt 8 -or
  $ProfileName -match '[\\/:\*\?"<>\|]' -or
  ($deniedProfiles -contains $ProfileName)
) {
  throw "Invalid AGENT_BROWSER_WIN_PROFILE '$ProfileName' (need >=8 chars, folder-safe, not a Chrome reserved name)"
}

$ProfileDir = Join-Path $env:LOCALAPPDATA "Google\Chrome\$ProfileName"
# Normalized forms for command-line matching (quoted/unquoted, slash variants)
$ProfileDirSlash = $ProfileDir -replace '\\', '/'

if ($CdpPortOverride) {
  $CdpPort = [int]$CdpPortOverride
} elseif ($env:AGENT_BROWSER_WIN_CDP_PORT) {
  $CdpPort = [int]$env:AGENT_BROWSER_WIN_CDP_PORT
} else {
  $CdpPort = 9222
}

if ($CdpPort -lt 1024 -or $CdpPort -gt 65535) {
  throw "Invalid AGENT_BROWSER_WIN_CDP_PORT '$CdpPort' (use 1024-65535)"
}

if ($SessionOverride) {
  $Session = $SessionOverride
} elseif ($env:AGENT_BROWSER_WIN_SESSION) {
  $Session = $env:AGENT_BROWSER_WIN_SESSION
} else {
  # Do NOT inherit bare AGENT_BROWSER_SESSION — it collides with Linux agent-browser
  # experiments and causes "Daemon version mismatch" against the Windows bridge.
  $Session = "win-agent-profile"
}

$script:LockMutex = $null
$script:LockAcquired = $false

function Enter-AgentBrowserLock {
  # Per profile+port so intentional multi-profile setups do not block each other.
  $name = "Local\AgentBrowserWin_{0}_{1}" -f $ProfileName, $CdpPort
  $script:LockMutex = New-Object System.Threading.Mutex($false, $name)
  $script:LockAcquired = $script:LockMutex.WaitOne(120000)
  if (-not $script:LockAcquired) {
    throw "Timed out waiting for agent-browser-win lock ($name). Another call may be stuck — retry or stop."
  }
}

function Exit-AgentBrowserLock {
  if ($script:LockMutex -and $script:LockAcquired) {
    try { [void]$script:LockMutex.ReleaseMutex() } catch {}
    $script:LockAcquired = $false
  }
  if ($script:LockMutex) {
    try { $script:LockMutex.Dispose() } catch {}
    $script:LockMutex = $null
  }
}

function Test-CdpHttp {
  try {
    $null = Invoke-WebRequest -UseBasicParsing "http://127.0.0.1:$CdpPort/json/version" -TimeoutSec 2
    return $true
  } catch {
    return $false
  }
}

function Test-CommandLineIsOurProfile {
  param([string]$CommandLine)
  if (-not $CommandLine) { return $false }
  # Prefer full --user-data-dir match over bare ProfileName substring.
  $patterns = @(
    ('--user-data-dir="{0}"' -f $ProfileDir),
    ('--user-data-dir={0}' -f $ProfileDir),
    ('--user-data-dir="{0}"' -f $ProfileDirSlash),
    ('--user-data-dir={0}' -f $ProfileDirSlash)
  )
  foreach ($p in $patterns) {
    if ($CommandLine.IndexOf($p, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
      return $true
    }
  }
  return $false
}

function Test-CommandLineHasOurCdpPort {
  param([string]$CommandLine)
  if (-not $CommandLine) { return $false }
  return ($CommandLine -match ("--remote-debugging-port[=:]?{0}\b" -f $CdpPort))
}

function Get-ListeningPidOnPort {
  param([int]$Port)
  try {
    $conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
      Select-Object -First 1
    if ($conn) { return [int]$conn.OwningProcess }
  } catch {}

  # Fallback: netstat (works without Get-NetTCPConnection module quirks)
  try {
    $lines = netstat -ano -p tcp 2>$null
    foreach ($line in $lines) {
      if ($line -match ("^\s*TCP\s+127\.0\.0\.1:{0}\s+\S+\s+LISTENING\s+(\d+)\s*$" -f $Port) -or
          $line -match ("^\s*TCP\s+0\.0\.0\.0:{0}\s+\S+\s+LISTENING\s+(\d+)\s*$" -f $Port) -or
          $line -match ("^\s*TCP\s+\[::\]:{0}\s+\S+\s+LISTENING\s+(\d+)\s*$" -f $Port) -or
          $line -match ("^\s*TCP\s+\[::1\]:{0}\s+\S+\s+LISTENING\s+(\d+)\s*$" -f $Port)) {
        return [int]$Matches[1]
      }
    }
  } catch {}
  return $null
}

function Get-CdpOwnerInfo {
  # Returns: HttpOk, Pid, IsOurs, ProcessName, CommandLine
  $info = [ordered]@{
    HttpOk      = (Test-CdpHttp)
    Pid         = $null
    IsOurs      = $false
    ProcessName = $null
    CommandLine = $null
  }
  if (-not $info.HttpOk) { return [pscustomobject]$info }

  $ownerPid = Get-ListeningPidOnPort -Port $CdpPort
  $info.Pid = $ownerPid
  if ($ownerPid) {
    $proc = Get-CimInstance Win32_Process -Filter "ProcessId = $ownerPid" -ErrorAction SilentlyContinue
    if ($proc) {
      $info.ProcessName = $proc.Name
      $info.CommandLine = $proc.CommandLine
      $info.IsOurs = (
        ($proc.Name -eq "chrome.exe") -and
        (Test-CommandLineIsOurProfile -CommandLine $proc.CommandLine) -and
        (Test-CommandLineHasOurCdpPort -CommandLine $proc.CommandLine)
      )
    }
  }

  # Fallback when TCP owner lookup is flaky but our profile Chrome clearly has the port.
  if (-not $info.IsOurs) {
    $ours = @(
      Get-AgentChromeProcesses | Where-Object {
        Test-CommandLineHasOurCdpPort -CommandLine $_.CommandLine
      }
    )
    if ($ours.Count -gt 0) {
      # Only claim ownership if we did not identify a different non-chrome listener.
      if (-not $info.ProcessName -or $info.ProcessName -eq "chrome.exe") {
        $info.IsOurs = $true
        $info.ProcessName = "chrome.exe"
        $info.CommandLine = $ours[0].CommandLine
        if (-not $info.Pid) { $info.Pid = [int]$ours[0].ProcessId }
      }
    }
  }
  return [pscustomobject]$info
}

function Test-OurCdp {
  $o = Get-CdpOwnerInfo
  return [bool]($o.HttpOk -and $o.IsOurs)
}

function Get-AgentChromeProcesses {
  Get-CimInstance Win32_Process -Filter "Name = 'chrome.exe'" -ErrorAction SilentlyContinue |
    Where-Object {
      $_.CommandLine -and
      $_.CommandLine -notlike "*--type=*" -and
      (Test-CommandLineIsOurProfile -CommandLine $_.CommandLine)
    }
}

function Get-AgentBrowserExe {
  $cmd = Get-Command agent-browser -ErrorAction SilentlyContinue
  if ($cmd) {
    $basedir = Split-Path $cmd.Source -Parent
    $exe = Join-Path $basedir "node_modules\agent-browser\bin\agent-browser-win32-x64.exe"
    if (Test-Path $exe) { return $exe }
  }
  $candidates = @(
    (Join-Path $env:APPDATA "fnm\aliases\default\node_modules\agent-browser\bin\agent-browser-win32-x64.exe"),
    (Join-Path $env:APPDATA "npm\node_modules\agent-browser\bin\agent-browser-win32-x64.exe"),
    (Join-Path $env:LOCALAPPDATA "npm\node_modules\agent-browser\bin\agent-browser-win32-x64.exe")
  )
  foreach ($c in $candidates) {
    if (Test-Path $c) { return $c }
  }
  return $null
}

function Reset-SessionDaemon {
  # Stale daemon metadata causes "Daemon version mismatch" hangs on --cdp.
  # Scope cleanup to THIS session so other profile/port bridges stay alive.
  $stateDir = Join-Path $env:USERPROFILE ".agent-browser"
  if (Test-Path $stateDir) {
    Get-ChildItem $stateDir -Filter "$Session*" -ErrorAction SilentlyContinue |
      Remove-Item -Force -ErrorAction SilentlyContinue
  }
  Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object {
      $_.Name -and
      ($_.Name -like "agent-browser*") -and
      $_.CommandLine -and
      (
        $_.CommandLine -like "*--session*$Session*" -or
        $_.CommandLine -like "*$Session*"
      )
    } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

function Start-AgentChrome {
  if (-not $ChromeExe) {
    throw "Google Chrome not found under Program Files / LocalAppData"
  }

  New-Item -ItemType Directory -Force -Path $ProfileDir | Out-Null
  Reset-SessionDaemon

  $owner = Get-CdpOwnerInfo
  if ($owner.HttpOk) {
    if ($owner.IsOurs) {
      Write-Output "CDP already listening (ours) on $CdpPort (PID $($owner.Pid))"
      return
    }
    $who = if ($owner.ProcessName) { "$($owner.ProcessName) PID $($owner.Pid)" } else { "unknown process" }
    throw ("Port {0} CDP is up but owned by {1}, not profile '{2}'. Set AGENT_BROWSER_WIN_CDP_PORT to a free port." -f $CdpPort, $who, $ProfileName)
  }

  $existing = @(Get-AgentChromeProcesses)
  if ($existing.Count -gt 0) {
    Write-Output "Stopping stale $ProfileName Chrome (no CDP)..."
    $existing | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 2
  }

  # Clear orphaned SingletonLock if no chrome holds this profile (prevents silent start failure).
  $lockFile = Join-Path $ProfileDir "SingletonLock"
  if ((Test-Path $lockFile) -and (@(Get-AgentChromeProcesses)).Count -eq 0) {
    Remove-Item -LiteralPath $lockFile -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $ProfileDir "SingletonCookie") -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $ProfileDir "SingletonSocket") -Force -ErrorAction SilentlyContinue
  }

  $argString = @(
    "--remote-debugging-port=$CdpPort"
    "--remote-allow-origins=*"
    "--user-data-dir=`"$ProfileDir`""
    "--profile-directory=Default"
    "--no-first-run"
    "--no-default-browser-check"
    "--new-window"
    "https://accounts.google.com/"
  ) -join " "

  Write-Output "Starting $ProfileName Chrome (CDP $CdpPort)..."
  Write-Output "Profile: $ProfileDir"
  Start-Process -FilePath $ChromeExe -ArgumentList $argString

  for ($i = 0; $i -lt 25; $i++) {
    if (Test-OurCdp) {
      Write-Output "CDP ready on http://127.0.0.1:$CdpPort (ours)"
      # Warm up first CDP attach (first command after launch is occasionally sticky)
      $exe = Get-AgentBrowserExe
      if ($exe) {
        $null = Invoke-NativeAgentBrowser -Exe $exe -ArgList @("--session", $Session, "--cdp", "$CdpPort", "get", "url") -TimeoutMs 20000
      }
      Write-Output "Log in in that Chrome window if needed. Session persists in the profile."
      return
    }
    Start-Sleep -Seconds 1
  }

  $final = Get-CdpOwnerInfo
  if ($final.HttpOk -and -not $final.IsOurs) {
    throw ("CDP came up on {0} but is not our profile (PID {1} {2})" -f $CdpPort, $final.Pid, $final.ProcessName)
  }
  throw "CDP did not become ready on port $CdpPort for profile $ProfileName"
}

function Stop-AgentChrome {
  $exe = Get-AgentBrowserExe
  if ($exe) {
    $null = Invoke-NativeAgentBrowser -Exe $exe -ArgList @("--session", $Session, "close") -TimeoutMs 15000
  }
  Reset-SessionDaemon

  $procs = @(Get-AgentChromeProcesses)
  if ($procs.Count -eq 0) {
    Write-Output "No $ProfileName Chrome running"
  } else {
    $procs | ForEach-Object {
      Write-Output "Stopping PID $($_.ProcessId)"
      Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }
    Get-CimInstance Win32_Process -Filter "Name = 'chrome.exe'" -ErrorAction SilentlyContinue |
      Where-Object { Test-CommandLineIsOurProfile -CommandLine $_.CommandLine } |
      ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 1
    Write-Output "Stopped"
  }
}

function Show-Status {
  $owner = Get-CdpOwnerInfo
  $cdpState = if (-not $owner.HttpOk) {
    "down"
  } elseif ($owner.IsOurs) {
    "up (ours PID $($owner.Pid))"
  } else {
    "up (FOREIGN $($owner.ProcessName) PID $($owner.Pid))"
  }
  Write-Output "Profile: $ProfileDir"
  Write-Output "Profile exists: $(Test-Path $ProfileDir)"
  Write-Output "CDP ${CdpPort}: $cdpState"
  $procs = @(Get-AgentChromeProcesses)
  Write-Output "Agent Chrome processes: $($procs.Count)"
  $exe = Get-AgentBrowserExe
  if ($exe) {
    Write-Output "agent-browser exe: $exe"
    Write-Output "agent-browser: $((& $exe --version) -join ' ')"
  } else {
    Write-Output "agent-browser: NOT FOUND (run setup / npm i -g agent-browser on Windows)"
  }
  if ($ChromeExe) {
    Write-Output "chrome: $ChromeExe"
  } else {
    Write-Output "chrome: NOT FOUND"
  }
}

function Show-Doctor {
  Show-Status
  Write-Output "----"
  Write-Output "USERPROFILE=$env:USERPROFILE"
  Write-Output "LOCALAPPDATA=$env:LOCALAPPDATA"
  Write-Output "Session=$Session"
  Write-Output "ProfileName=$ProfileName"

  $npm = Get-Command npm -ErrorAction SilentlyContinue
  if ($npm) {
    Write-Output "npm: $($npm.Source)"
  } else {
    Write-Output "npm: NOT FOUND on Windows PATH"
  }

  $owner = Get-CdpOwnerInfo
  if ($owner.HttpOk) {
    try {
      $ver = (Invoke-WebRequest -UseBasicParsing "http://127.0.0.1:$CdpPort/json/version" -TimeoutSec 2).Content
      Write-Output "CDP /json/version OK (ours=$($owner.IsOurs) pid=$($owner.Pid) name=$($owner.ProcessName))"
      Write-Output $ver
    } catch {
      Write-Output "CDP probe failed: $($_.Exception.Message)"
    }
  } else {
    Write-Output "CDP HTTP: down"
  }

  $stateDir = Join-Path $env:USERPROFILE ".agent-browser"
  if (Test-Path $stateDir) {
    $stale = @(Get-ChildItem $stateDir -Filter "$Session*" -ErrorAction SilentlyContinue)
    Write-Output "daemon state files for session: $($stale.Count)"
  } else {
    Write-Output "daemon state dir: missing (ok until first run)"
  }

  $lockName = "Local\AgentBrowserWin_{0}_{1}" -f $ProfileName, $CdpPort
  Write-Output "lock name: $lockName"

  $problems = @()
  if (-not $ChromeExe) { $problems += "chrome missing" }
  if (-not (Get-AgentBrowserExe)) { $problems += "agent-browser missing" }
  if ($owner.HttpOk -and -not $owner.IsOurs) {
    $problems += "CDP port $CdpPort owned by foreign process"
  }
  if ($problems.Count -gt 0) {
    Write-Output ("doctor FAIL: " + ($problems -join ", "))
    throw ("doctor FAIL: " + ($problems -join ", "))
  }
  Write-Output "doctor PASS"
}

function Invoke-NativeAgentBrowser {
  param(
    [string]$Exe,
    [string[]]$ArgList,
    [int]$TimeoutMs = 45000
  )

  $outFile = Join-Path $env:TEMP ("agent-browser-win-out-{0}-{1}.txt" -f $PID, [Guid]::NewGuid().ToString("N"))
  $errFile = Join-Path $env:TEMP ("agent-browser-win-err-{0}-{1}.txt" -f $PID, [Guid]::NewGuid().ToString("N"))
  Remove-Item $outFile, $errFile -Force -ErrorAction SilentlyContinue

  $p = Start-Process -FilePath $Exe `
    -ArgumentList $ArgList `
    -WorkingDirectory $env:USERPROFILE `
    -NoNewWindow -PassThru `
    -RedirectStandardOutput $outFile `
    -RedirectStandardError $errFile

  $finished = $p.WaitForExit($TimeoutMs)
  if (-not $finished) {
    try { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } catch {}
    $stdout = $(if (Test-Path $outFile) { Get-Content -LiteralPath $outFile -Raw -ErrorAction SilentlyContinue } else { "" })
    $stderr = $(if (Test-Path $errFile) { Get-Content -LiteralPath $errFile -Raw -ErrorAction SilentlyContinue } else { "" })
    Remove-Item $outFile, $errFile -Force -ErrorAction SilentlyContinue
    return [pscustomobject]@{
      TimedOut = $true
      ExitCode = -1
      StdOut = $stdout
      StdErr = $stderr
    }
  }

  $p.Refresh()
  $code = $p.ExitCode
  $stdout = $(if (Test-Path $outFile) { Get-Content -LiteralPath $outFile -Raw -ErrorAction SilentlyContinue } else { "" })
  $stderr = $(if (Test-Path $errFile) { Get-Content -LiteralPath $errFile -Raw -ErrorAction SilentlyContinue } else { "" })
  Remove-Item $outFile, $errFile -Force -ErrorAction SilentlyContinue
  return [pscustomobject]@{
    TimedOut = $false
    ExitCode = $code
    StdOut = $stdout
    StdErr = $stderr
  }
}

function Invoke-AgentBrowser([string[]]$BrowserArgs) {
  $exe = Get-AgentBrowserExe
  if (-not $exe) {
    throw "agent-browser exe not found. Run: scripts/setup_agent_browser_win.sh (or npm i -g agent-browser on Windows)"
  }
  if (-not (Test-OurCdp)) {
    $owner = Get-CdpOwnerInfo
    if ($owner.HttpOk -and -not $owner.IsOurs) {
      throw ("Cannot attach: port {0} CDP owned by {1} PID {2}, not '{3}'" -f $CdpPort, $owner.ProcessName, $owner.Pid, $ProfileName)
    }
    Start-AgentChrome
  }

  $env:AGENT_BROWSER_SESSION = $Session
  if ($BrowserArgs.Count -eq 0) {
    $BrowserArgs = @("get", "url")
  }

  # IMPORTANT: do not call `& $exe ...` — under powershell.exe from WSL the CLI can
  # spawn a daemon child and the parent console never returns.
  $argList = @("--session", $Session, "--cdp", "$CdpPort") + @($BrowserArgs)

  $result = Invoke-NativeAgentBrowser -Exe $exe -ArgList $argList -TimeoutMs 45000
  # Retry only on hard failure/timeout. Do NOT retry on ExitCode=$null — WinPS 5.1
  # Start-Process redirects often leave ExitCode null after a successful run.
  $needRetry = $result.TimedOut -or (($null -ne $result.ExitCode) -and ([int]$result.ExitCode -ne 0))
  if ($needRetry) {
    Reset-SessionDaemon
    Start-Sleep -Milliseconds 500
    $result = Invoke-NativeAgentBrowser -Exe $exe -ArgList $argList -TimeoutMs 45000
  }

  $stdout = if ($null -eq $result.StdOut) { "" } else { [string]$result.StdOut }
  $stderr = if ($null -eq $result.StdErr) { "" } else { [string]$result.StdErr }
  if ($stdout.Trim().Length -gt 0) { Write-Output $stdout.TrimEnd() }
  if ($stderr.Trim().Length -gt 0) { Write-Output $stderr.TrimEnd() }

  $combined = $stdout + "`n" + $stderr
  if ($combined -match '(?i)Unknown command') {
    throw "agent-browser rejected command (unknown command)"
  }
  if ($result.TimedOut) {
    throw "agent-browser timed out after retry"
  }
  # Windows PowerShell 5.1 + Start-Process redirects often leave ExitCode $null
  # even after a successful HasExited run. Treat null as 0 unless output looks like failure.
  $code = $result.ExitCode
  if ($null -eq $code) {
    if ($combined -match '(?i)\b(error|failed|rejected)\b') {
      throw "agent-browser failed without an exit code"
    }
    $code = 0
  }
  if ([int]$code -ne 0) {
    throw "agent-browser exited with code $code"
  }
}

Set-Location $env:USERPROFILE

$script:ExitCode = 0
try {
  Enter-AgentBrowserLock
  switch ($Action) {
    { $_ -in @("start", "up") } { Start-AgentChrome }
    { $_ -in @("stop", "down") } { Stop-AgentChrome }
    { $_ -in @("status", "st") } { Show-Status }
    "doctor" { Show-Doctor }
    "run" {
      $parsed = [string[]]@()
      if ($ArgsBase64 -and $ArgsBase64.Trim() -ne "") {
        $json = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($ArgsBase64))
        # PS 5.1: do NOT wrap ConvertFrom-Json array in @() — that nests it and stringifies to "a b"
        $raw = ConvertFrom-Json -InputObject $json
        if ($null -eq $raw) {
          $parsed = [string[]]@()
        } elseif ($raw -is [System.Array]) {
          $parsed = [string[]]$raw
        } else {
          $parsed = [string[]]@([string]$raw)
        }
      }
      Invoke-AgentBrowser -BrowserArgs $parsed
    }
    default { throw "Unknown action: $Action" }
  }
} catch {
  $script:ExitCode = 1
  Write-Error $_
} finally {
  Exit-AgentBrowserLock
}

# Daemon children spawned by agent-browser can keep powershell.exe alive under WSL.
# Force-terminate so the bash wrapper returns promptly.
[Environment]::Exit($script:ExitCode)
