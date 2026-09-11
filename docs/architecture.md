# Architecture

Progressive disclosure: this page = map only. Procedures → [setup-stow.md](setup-stow.md).

## Layers

| Layer | Path | Owns |
| --- | --- | --- |
| Provisioning | `ansible/` | packages, pinned installs, first-time system state (Ubuntu) |
| Config links | `stow/` | `$HOME`-mirroring symlinks (1 app = 1 package) |
| Bootstrap | `setup.sh` | Ubuntu layer always; Windows layer when WSL+interop detected |
| Day-to-day links | `stow.sh` | `stow` / `unstow` / `restow` without full setup |
| Windows+WSL | `windows/` | host extras via `windows/setup.sh` (`.wslconfig`, agent-browser-win, WezTerm) |
| Agent skills | `skills/` | sources; installers copy to `~/.cursor/skills` |
| Deep docs | `docs/` | this tree |
| Agent entry | `AGENTS.md` | always-short topic map |

## Detection

| Environment | `./setup.sh` runs |
| --- | --- |
| Pure Ubuntu (no `powershell.exe`) | Ansible + optional bws |
| WSL2 + Windows | above + `windows/setup.sh` |
| Force Ubuntu only | `./setup.sh --ubuntu-only` |
| Windows layer only | `./setup.sh --windows-only` |

## Data flow

```text
ansible/group_vars/all.yml  →  pins + stow_packages
setup.sh (Ubuntu)           →  ansible roles + optional bws
stow/<pkg>/                 →  ./stow.sh restow  →  $HOME symlinks
setup.sh (WSL) / windows/   →  .wslconfig + agent-browser-win + WezTerm

Ctrl+Alt+I → terminal-browser-open
  native → herdr plugin open-split
  WSL    → tb-split → windows/wezterm/tb-split.{sh,ps1}
```

## Ansible roles (tags)

| Role / area | Typical tags |
| --- | --- |
| base packages | `base` |
| shell tooling | `shell` |
| Node / npm globals | `node` |
| herdr, TB, genmedia, … | `tools`, `herdr`, `terminal-browser` |
| Stow apply | `dotfiles`, `stow` |

## Config edit rule

1. Change files under `stow/<pkg>/…` (paths relative to `$HOME`)
2. `./stow.sh restow <pkg>`
3. App-specific reload if needed (e.g. `herdr server reload-config`)

Do not invent parallel copy paths under `~` outside Stow.
Windows host files live under `windows/` and are applied by `windows/*/setup.sh`, not Stow.
