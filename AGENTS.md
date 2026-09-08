# AGENTS.md — inovue/dotfiles

WSL2 Ubuntu + Windows host helpers. **Ansible provisions; Stow links configs.**  
Human onboarding: [README.md](README.md). Doc index: [docs/README.md](docs/README.md).

## Do not

- Put secrets in `.env` — use `bws` ([docs/bws.md](docs/bws.md))
- Hack Windows default Chrome User Data + CDP — use `agent-browser-win`
- Hand-`ln` configs — edit `stow/<pkg>/` then `./stow.sh restow <pkg>`

## Topic map (read only what you need)

| Need | Doc |
| --- | --- |
| Layout / Ansible vs Stow vs `windows/` | [docs/architecture.md](docs/architecture.md) |
| `setup.sh` / tags / pins / adding a stow pkg | [docs/setup-stow.md](docs/setup-stow.md) |
| herdr, hunk-diff, terminal-browser keys | [docs/herdr.md](docs/herdr.md) |
| WezTerm nightly, TB black screen, JP IME | [windows/wezterm/README.md](windows/wezterm/README.md) |
| Secrets / FAL_KEY / `bws run` | [docs/bws.md](docs/bws.md) (developer section) |
| Logged-in Windows Chrome | skill `agent-browser-win` + [docs/agent-browser-win.md](docs/agent-browser-win.md) |
| LP / genmedia grids | skill `asset-generator` (+ `skills/asset-generator/references/`) |
| Windows host layout | [windows/README.md](windows/README.md) |

## Browser router (pick one)

| Goal | Tool |
| --- | --- |
| Visual browser beside agent (Kitty graphics) | `terminal-browser` / herdr `Ctrl+B Shift+B` → drive with `terminal-browser action` |
| Linux automation, no Win login | `agent-browser` (Linux) |
| Real Win login (Gmail / SSO) | `agent-browser-win` only |

## Edit conventions

- App config → `stow/<name>/` mirroring `$HOME` → `./stow.sh restow <name>`
- Version pins / `stow_packages` → `ansible/group_vars/all.yml` → `./setup.sh --tags …`
- Skill sources → `skills/<name>/`; installers → `scripts/`
- After herdr config change → `herdr server reload-config`
