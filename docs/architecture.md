# Architecture

Ubuntu CLI only. Procedures → [setup-stow.md](setup-stow.md).

## Layers

| Layer | Path | Owns |
| --- | --- | --- |
| Provisioning | `ansible/` | packages, pinned installs |
| Config links | `stow/` | `$HOME`-mirroring symlinks (1 app = 1 package) |
| Bootstrap | `setup.sh` | Ansible + optional bws |
| Day-to-day | `stow.sh` | `stow` / `unstow` / `restow` |
| Helpers | `scripts/` | `setup_bws.sh`, `setup_rtk.sh` |
| Docs | `docs/` | this tree |
| Agent entry | `AGENTS.md` | short topic map |

## Data flow

```text
ansible/group_vars/all.yml  →  pins + stow_packages
setup.sh                    →  ansible roles + optional bws
stow/<pkg>/                 →  ./stow.sh restow  →  $HOME symlinks
```

## Ansible roles (tags)

| Role | Tags |
| --- | --- |
| base packages | `base` |
| shell tooling | `shell` |
| Node | `node` |
| herdr, genmedia, … | `tools`, `herdr` |
| Stow apply | `dotfiles`, `stow` |

## Config edit rule

1. Change files under `stow/<pkg>/…`
2. `./stow.sh restow <pkg>`
3. Reload if needed (`herdr server reload-config`)
