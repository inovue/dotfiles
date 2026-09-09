#!/usr/bin/env bash
# If a herdr server is running a replaced (deleted) binary, live-handoff onto
# the on-disk binary. Keeps panes when live-handoff works; otherwise stops the
# stale server so the next `herdr` attach starts fresh.
#
# Prints one of: skipped | handed_off | stopped
set -euo pipefail

export PATH="${HOME}/.local/bin:${PATH}"

if ! command -v herdr >/dev/null 2>&1; then
  echo "skipped"
  exit 0
fi

need_handoff=0
if status_json="$(herdr status --json 2>/dev/null)"; then
  eval "$(
    printf '%s' "$status_json" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit(0)
server = d.get("server") or {}
update = d.get("update") or {}
running = bool(server.get("running") or server.get("status") == "running")
stale = bool(server.get("server_binary_stale") or update.get("server_binary_stale"))
restart = bool(server.get("restart_needed") or update.get("restart_needed"))
print(f"running={1 if running else 0}")
print(f"stale={1 if (stale or restart) else 0}")
'
  )"
  if [[ "${running:-0}" -eq 1 && "${stale:-0}" -eq 1 ]]; then
    need_handoff=1
  fi
fi

# Fallback: /proc exe still points at a replaced inode (status may lag / older herdr).
if [[ "$need_handoff" -eq 0 ]]; then
  while read -r pid; do
    [[ -n "$pid" ]] || continue
    exe="$(readlink "/proc/${pid}/exe" 2>/dev/null || true)"
    case "$exe" in
      *'(deleted)'*) need_handoff=1; break ;;
    esac
  done < <(pgrep -f '[h]erdr server' || true)
fi

if [[ "$need_handoff" -eq 0 ]]; then
  echo "skipped"
  exit 0
fi

if herdr server live-handoff; then
  echo "handed_off"
  exit 0
fi

herdr server stop || true
echo "stopped"
exit 0
