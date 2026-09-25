# AGENTS.md — inovue/dotfiles

Ubuntu CLI environment for server-side development. **Ansible provisions; Stow links configs.**  
Human onboarding: [README.md](README.md). Doc index: [docs/README.md](docs/README.md).

## Do not

- Put secrets in `.env` — use `bws` ([docs/bws.md](docs/bws.md))
- Hand-`ln` configs — edit `stow/<pkg>/` then `./stow.sh restow <pkg>`

## Topic map

| Need | Doc |
| --- | --- |
| Layout / Ansible vs Stow | [docs/architecture.md](docs/architecture.md) |
| `setup.sh` / tags / pins / adding a stow pkg | [docs/setup-stow.md](docs/setup-stow.md) |
| herdr, hunk-diff, terminal-browser | [docs/herdr.md](docs/herdr.md) |
| agent-browser | `./scripts/setup_agent_browser.sh` — pin `agent_browser_pin` in `ansible/group_vars/all.yml`；公式 skill は global install |
| Secrets / FAL_KEY / `bws run` | [docs/bws.md](docs/bws.md) |
| RTK (Cursor CLI token filter) | `./scripts/setup_rtk.sh` — pin `rtk_pin` in `ansible/group_vars/all.yml` |

## Edit conventions

- App config → `stow/<name>/` → `./stow.sh restow <name>`
- Pins / `stow_packages` → `ansible/group_vars/all.yml` → `./setup.sh --tags …`
- Installers → `scripts/` (`setup_bws.sh`, `setup_rtk.sh`, `setup_agent_browser.sh`)
- After herdr config change → `herdr server reload-config`
