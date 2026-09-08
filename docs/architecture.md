# Architecture

Progressive disclosure: this page = map only. Procedures → [setup-stow.md](setup-stow.md).

## Layers

| Layer | Path | Owns |
| --- | --- | --- |
| Provisioning | `ansible/` | packages, pinned installs, first-time system state |
| Config links | `stow/` | `$HOME`-mirroring symlinks (1 app = 1 package) |
| Bootstrap | `setup.sh` | ansible + optional bws + agent-browser-win on WSL |
| Day-to-day links | `stow.sh` | `stow` / `unstow` / `restow` without full setup |
| Windows host | `windows/` | not Stow; WezTerm etc. via `windows/*/setup.sh` |
| Agent skills | `skills/` | sources; installers copy to `~/.cursor/skills` |
| Deep docs | `docs/` | this tree |
| Agent entry | `AGENTS.md` | always-short topic map |

## Data flow

```text
ansible/group_vars/all.yml  →  pins + stow_packages
setup.sh / ansible roles    →  install binaries + plugins
stow/<pkg>/                 →  ./stow.sh restow  →  $HOME symlinks
windows/wezterm/            →  setup.sh          →  %USERPROFILE%\.wezterm.lua
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
