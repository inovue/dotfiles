# Architecture

Ubuntu CLI only. Procedures → [setup-stow.md](setup-stow.md).

## Layers

| Layer | Path | Owns |
| --- | --- | --- |
| Provisioning | `ansible/` | apt packages, pinned installs, git identity |
| Config links | `stow/` | `$HOME`-mirroring symlinks (1 app = 1 package; every dir is linked) |
| Managed JSON | `managed/` | keys merged into app-owned JSON (`~/.claude/settings.json`) by `scripts/json_merge.py` |
| Secrets | `stow/secrets/` | `with-secrets`, per-tool shims ([bws.md](bws.md)) |
| Bootstrap | `setup.sh` | Ansible + optional bws token |
| Day-to-day | `stow.sh` | `stow` / `unstow` / `restow` (conflicts → `~/.local/state/inovue/stow-backup/`) |
| Health | `scripts/doctor.sh` | versions vs pins, secret hygiene, agent shell, hooks |

## Ansible roles

| Role | Tags | Notes |
| --- | --- | --- |
| base | `base`, `apt` | CLI + web dev apt packages, terminal-browser runtime libs |
| shell | `shell` | zsh login shell, starship, zoxide, sheldon |
| node | `node` | fnm + Node LTS, pnpm, bun, hunkdiff |
| tools | `tools`, `herdr`, `terminal-browser`, `agent-browser` | everything else |
| git | `git` | identity only (from `-e` vars or `gh api user`) |
| docker | `docker` (opt-in, tagged `never`) | docker.io + compose v2 |
| dotfiles | `dotfiles`, `stow`, `claude` | `stow.sh restow` + managed JSON merge |

## Pin policy (`ansible/group_vars/all.yml`)

- **Exact**: each installer has a `check` command; setup (re)installs when the reported version ≠ pin, then verifies. Installers run under `set -euo pipefail`.
- **Bootstrap**: tools that update themselves (claude, herdr, flyctl) are installed only when missing; setup never downgrades them.
- Stamps in `~/.config/inovue/tool-pins/` remain only for things without a version command (herdr plugins).

## Shell model

- `.zshenv` (every zsh): PATH only — secret shims first, then `~/.local/bin`, fnm default Node, etc. No secrets.
- `.zshrc`: fnm, then **returns early for coding agents** (`CLAUDECODE`, `CURSOR_AGENT`, `INOVUE_AGENT_SHELL`). Humans get aliases, zoxide `cd`, starship, sheldon, fzf.
