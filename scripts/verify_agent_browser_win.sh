#!/usr/bin/env bash
# Severe end-to-end verification for agent-browser-win bridge.
# Exit non-zero on first hard failure. Soft warnings printed but counted.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0
WARN=0
REPORT=()

ok() { PASS=$((PASS + 1)); REPORT+=("PASS  $*"); echo "PASS  $*"; }
bad() { FAIL=$((FAIL + 1)); REPORT+=("FAIL  $*"); echo "FAIL  $*"; }
soft() { WARN=$((WARN + 1)); REPORT+=("WARN  $*"); echo "WARN  $*"; }

require() {
  if "$@"; then ok "$*"; else bad "$*"; return 1; fi
}

run_to() {
  local secs="$1"; shift
  timeout "$secs" "$@"
}

AB="${HOME}/.local/bin/agent-browser-win"
[[ -x "$AB" ]] || AB="$ROOT/scripts/agent-browser-win.sh"

win_env() {
  powershell.exe -NoProfile -Command "[Console]::Out.Write([Environment]::GetEnvironmentVariable('$1','Process'))" 2>/dev/null | tr -d '\r'
}

LOCALAPPDATA_WIN="$(win_env LOCALAPPDATA)"
PROFILE_WSL="$(wslpath "$LOCALAPPDATA_WIN")/Google/Chrome/AgentBrowserProfile"
BACKUP_WSL="$(wslpath "$LOCALAPPDATA_WIN")/Google/Chrome/AgentBrowserProfile.verify-bak"
HELPER_WSL="$(wslpath "$LOCALAPPDATA_WIN")/agent-browser-win"

echo "==== 0. Preconditions ===="
command -v powershell.exe >/dev/null && ok "powershell.exe present" || bad "powershell.exe missing"
command -v python3 >/dev/null && ok "python3 present" || bad "python3 missing"
[[ -n "$LOCALAPPDATA_WIN" ]] && ok "LOCALAPPDATA=$LOCALAPPDATA_WIN" || bad "LOCALAPPDATA empty"
[[ -f "$ROOT/scripts/agent-browser-win.sh" ]] && ok "repo sh present" || bad "repo sh missing"
[[ -f "$ROOT/scripts/agent-browser-win.ps1" ]] && ok "repo ps1 present" || bad "repo ps1 missing"
[[ -f "$ROOT/skills/agent-browser-win/SKILL.md" ]] && ok "skill source present" || bad "skill source missing"
[[ -f "$ROOT/docs/agent-browser-win.md" ]] && ok "docs present" || bad "docs missing"

echo "==== 1. No hardcoded username paths in scripts ===="
if rg -n "Users\\\\inovu|Users/inovu|/home/inovue" \
  "$ROOT/scripts/agent-browser-win.sh" \
  "$ROOT/scripts/agent-browser-win.ps1" \
  "$ROOT/scripts/setup_agent_browser_win.sh" \
  "$ROOT/scripts/setup_agent_browser_win.ps1" \
  "$ROOT/skills/agent-browser-win/SKILL.md" 2>/dev/null; then
  bad "hardcoded user path found"
else
  ok "no hardcoded user paths in bridge scripts/skill"
fi

echo "==== 2. Symlink / PATH wrapper ===="
if [[ -L "${HOME}/.local/bin/agent-browser-win" || -x "${HOME}/.local/bin/agent-browser-win" ]]; then
  ok "~/.local/bin/agent-browser-win exists"
  # Ensure symlink resolves to repo script
  resolved="$(readlink -f "${HOME}/.local/bin/agent-browser-win" 2>/dev/null || true)"
  if [[ -n "$resolved" && "$resolved" == *"/scripts/agent-browser-win.sh" ]]; then
    ok "symlink resolves to scripts/agent-browser-win.sh"
  else
    soft "symlink resolve unexpected: $resolved"
  fi
else
  bad "~/.local/bin/agent-browser-win missing"
fi

echo "==== 3. Idempotent setup (x2) ===="
bash "$ROOT/scripts/setup_agent_browser_win.sh" >/tmp/abw-setup1.txt 2>&1 && ok "setup run #1" || { bad "setup run #1"; sed -n '1,80p' /tmp/abw-setup1.txt; }
bash "$ROOT/scripts/setup_agent_browser_win.sh" >/tmp/abw-setup2.txt 2>&1 && ok "setup run #2 (idempotent)" || { bad "setup run #2"; sed -n '1,80p' /tmp/abw-setup2.txt; }

[[ -f "$HELPER_WSL/agent-browser-win.ps1" ]] && ok "Windows helper synced" || bad "Windows helper missing"
[[ -f "${HOME}/.cursor/skills/agent-browser-win/SKILL.md" ]] && ok "cursor skill installed" || bad "cursor skill missing"
[[ -f "${HOME}/.agents/skills/agent-browser-win/SKILL.md" ]] && ok "agents skill installed" || bad "agents skill missing"

# skill content matches source
if cmp -s "$ROOT/skills/agent-browser-win/SKILL.md" "${HOME}/.cursor/skills/agent-browser-win/SKILL.md"; then
  ok "cursor skill matches source"
else
  soft "cursor skill differs from source"
fi

echo "==== 4. Stop / clear daemon / backup profile ===="
run_to 60 "$AB" stop >/tmp/abw-stop.txt 2>&1 || soft "stop returned non-zero (may already be stopped)"
powershell.exe -NoProfile -Command 'Get-Process agent-browser* -EA SilentlyContinue | Stop-Process -Force' >/dev/null 2>&1 || true

BACKUP_OK=0
if [[ -d "$PROFILE_WSL" ]]; then
  if powershell.exe -NoProfile -Command '
    $ErrorActionPreference = "Stop"
    $src = Join-Path $env:LOCALAPPDATA "Google\Chrome\AgentBrowserProfile"
    $dst = Join-Path $env:LOCALAPPDATA "Google\Chrome\AgentBrowserProfile.verify-bak"
    if (Test-Path $dst) { Remove-Item -LiteralPath $dst -Recurse -Force }
    if (-not (Test-Path $src)) { throw "source profile missing" }
    & robocopy $src $dst /E /R:2 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
    # robocopy: 0-7 = success/partial, >=8 = failure
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed with $LASTEXITCODE" }
    if (-not (Test-Path $dst)) { throw "backup dir missing after robocopy" }
    Write-Output "backup_ok"
  ' >/tmp/abw-bak.txt 2>&1; then
    ok "profile backed up to AgentBrowserProfile.verify-bak"
    BACKUP_OK=1
  else
    bad "profile backup failed"
    cat /tmp/abw-bak.txt || true
  fi
else
  soft "no existing profile to backup"
  BACKUP_OK=1  # nothing to preserve
fi

echo "==== 5. Cold start after profile delete ===="
if [[ "$BACKUP_OK" -ne 1 ]]; then
  bad "skipping profile delete because backup failed"
else
  powershell.exe -NoProfile -Command '
    $src = Join-Path $env:LOCALAPPDATA "Google\Chrome\AgentBrowserProfile"
    if (Test-Path $src) { Remove-Item -LiteralPath $src -Recurse -Force }
    if (Test-Path $src) { throw "profile still exists" }
  ' >/tmp/abw-del.txt 2>&1 && ok "profile deleted" || { bad "profile delete failed"; cat /tmp/abw-del.txt; }
fi

# clear daemon state
powershell.exe -NoProfile -Command "
  Get-Process agent-browser* -EA SilentlyContinue | Stop-Process -Force
  \$d = Join-Path \$env:USERPROFILE '.agent-browser'
  if (Test-Path \$d) { Remove-Item \"\$d\*\" -Force -Recurse -EA SilentlyContinue }
" >/dev/null 2>&1 || true

run_to 120 "$AB" start >/tmp/abw-start-cold.txt 2>&1 && ok "cold start" || { bad "cold start"; cat /tmp/abw-start-cold.txt; }
run_to 30 "$AB" doctor >/tmp/abw-doctor-cold.txt 2>&1 && ok "doctor after cold start" || { bad "doctor after cold start"; cat /tmp/abw-doctor-cold.txt; }
rg -q "CDP .* up \(ours|CDP 9222: up \(ours" /tmp/abw-doctor-cold.txt && ok "CDP up (ours) after cold start" || bad "CDP not ours after cold start"
rg -q 'lock name: Local\\AgentBrowserWin_' /tmp/abw-doctor-cold.txt && ok "doctor reports mutex lock name" || soft "doctor missing lock name"

title="$(run_to 40 "$AB" get title 2>/tmp/abw-title-cold.err || true)"
echo "cold title: $title"
if echo "$title" | rg -qi "Google|ログイン|Sign in|Account"; then
  ok "cold start landed on Google login/account UI"
else
  soft "cold title unexpected: $title"
fi

echo "==== 6. Basic command stability (cold profile) ===="
run_to 40 "$AB" open https://example.com/ >/tmp/abw-ex.txt 2>&1 && ok "open example.com" || { bad "open example.com"; cat /tmp/abw-ex.txt; }
t="$(run_to 40 "$AB" get title 2>/dev/null || true)"
[[ "$t" == *Example* ]] && ok "get title Example Domain" || bad "get title got: $t"
run_to 40 "$AB" snapshot -i -c -d 2 >/tmp/abw-snap.txt 2>&1 && ok "snapshot" || { bad "snapshot"; cat /tmp/abw-snap.txt; }
rg -q "Example Domain|Learn more" /tmp/abw-snap.txt && ok "snapshot has expected nodes" || bad "snapshot content unexpected"

echo "==== 7. stop/start cycle x3 ===="
for i in 1 2 3; do
  run_to 60 "$AB" stop >/tmp/abw-cyc-stop-$i.txt 2>&1 || soft "cycle $i stop nonzero"
  sleep 1
  run_to 120 "$AB" start >/tmp/abw-cyc-start-$i.txt 2>&1 && ok "cycle $i start" || { bad "cycle $i start"; cat /tmp/abw-cyc-start-$i.txt; }
  run_to 60 "$AB" open https://example.com/ >/tmp/abw-cyc-open-$i.txt 2>&1 && ok "cycle $i open" || bad "cycle $i open"
  t="$(run_to 40 "$AB" get title 2>/dev/null || true)"
  [[ "$t" == *Example* ]] && ok "cycle $i title" || bad "cycle $i title=$t"
done

echo "==== 8. Restore login profile & verify Gmail ===="
run_to 60 "$AB" stop >/tmp/abw-stop2.txt 2>&1 || true
powershell.exe -NoProfile -Command 'Get-Process agent-browser* -EA SilentlyContinue | Stop-Process -Force' >/dev/null 2>&1 || true
if powershell.exe -NoProfile -Command '
  $ErrorActionPreference = "Stop"
  Get-Process agent-browser* -EA SilentlyContinue | Stop-Process -Force
  $src = Join-Path $env:LOCALAPPDATA "Google\Chrome\AgentBrowserProfile.verify-bak"
  $dst = Join-Path $env:LOCALAPPDATA "Google\Chrome\AgentBrowserProfile"
  if (-not (Test-Path $src)) { throw "backup missing" }
  if (Test-Path $dst) { Remove-Item -LiteralPath $dst -Recurse -Force }
  & robocopy $src $dst /E /R:2 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "robocopy restore failed $LASTEXITCODE" }
  Write-Output "restore_ok"
' >/tmp/abw-restore.txt 2>&1; then
  ok "profile restored from backup"
else
  bad "profile restore failed"
  cat /tmp/abw-restore.txt || true
fi

run_to 60 "$AB" start >/tmp/abw-start-restored.txt 2>&1 && ok "start with restored profile" || bad "start restored"
run_to 50 "$AB" open https://mail.google.com/mail/u/0/ >/tmp/abw-gmail.txt 2>&1 && ok "open gmail" || { bad "open gmail"; cat /tmp/abw-gmail.txt; }
gt="$(run_to 40 "$AB" get title 2>/dev/null || true)"
echo "gmail title: $gt"
if echo "$gt" | rg -qi "受信トレイ|Inbox|Gmail"; then
  ok "Gmail login persisted after backup/restore"
else
  bad "Gmail not logged in after restore: $gt"
fi
gu="$(run_to 40 "$AB" get url 2>/dev/null || true)"
echo "gmail url: $gu"
if echo "$gu" | rg -q "mail.google.com/mail"; then
  ok "Gmail URL looks authenticated (not accounts redirect)"
else
  soft "Gmail URL unexpected: $gu"
fi

echo "==== 9. Negative checks (documented failure modes) ===="
# WSL direct CDP to 9222 should fail or not be used — we just confirm localhost from WSL is not Windows CDP reliably
if curl -sS -m 2 http://127.0.0.1:9222/json/version >/dev/null 2>&1; then
  soft "WSL localhost:9222 unexpectedly reachable (mirrored networking?). Bridge still preferred."
else
  ok "WSL cannot hit Windows CDP on 127.0.0.1:9222 (expected on NAT)"
fi

# Invalid profile name must be rejected by PS1
if AGENT_BROWSER_WIN_PROFILE=Default run_to 30 "$AB" status >/tmp/abw-bad-profile.txt 2>&1; then
  bad "PROFILE=Default should be rejected"
else
  ok "PROFILE=Default rejected"
fi
if AGENT_BROWSER_WIN_PROFILE=ab run_to 30 "$AB" status >/tmp/abw-short-profile.txt 2>&1; then
  bad "short PROFILE should be rejected"
else
  ok "short PROFILE rejected"
fi

echo "==== 9b. Mutex / serialised parallel calls ===="
# Two overlapping status calls should both succeed (mutex serialises; no corrupt state)
run_to 60 "$AB" status >/tmp/abw-par1.txt 2>&1 &
pid1=$!
run_to 60 "$AB" status >/tmp/abw-par2.txt 2>&1 &
pid2=$!
ec1=0; wait "$pid1" || ec1=$?
ec2=0; wait "$pid2" || ec2=$?
if [[ "$ec1" -eq 0 && "$ec2" -eq 0 ]]; then
  ok "parallel status both succeeded (mutex)"
else
  bad "parallel status failed ec1=$ec1 ec2=$ec2"
fi
# Overlapping get title while CDP is up
run_to 60 "$AB" get title >/tmp/abw-par-t1.txt 2>&1 &
pid1=$!
run_to 60 "$AB" get title >/tmp/abw-par-t2.txt 2>&1 &
pid2=$!
ec1=0; wait "$pid1" || ec1=$?
ec2=0; wait "$pid2" || ec2=$?
t1="$(tr -d '\r' </tmp/abw-par-t1.txt | tail -n1)"
t2="$(tr -d '\r' </tmp/abw-par-t2.txt | tail -n1)"
if [[ "$ec1" -eq 0 && "$ec2" -eq 0 && -n "$t1" && -n "$t2" ]]; then
  ok "parallel get title both succeeded"
else
  bad "parallel get title failed ec1=$ec1 ec2=$ec2 t1=$t1 t2=$t2"
fi

echo "==== 10. Cleanup backup (keep live profile) ===="
powershell.exe -NoProfile -Command "
  \$bak = Join-Path \$env:LOCALAPPDATA 'Google\Chrome\AgentBrowserProfile.verify-bak'
  if (Test-Path \$bak) { Remove-Item -LiteralPath \$bak -Recurse -Force }
" >/dev/null 2>&1 && ok "removed verify-bak" || soft "could not remove verify-bak"

echo
echo "======== SUMMARY ========"
printf '%s\n' "${REPORT[@]}"
echo "-------------------------"
echo "PASS=$PASS WARN=$WARN FAIL=$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
