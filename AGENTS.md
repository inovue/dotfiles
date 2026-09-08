# AGENTS.md — inovue/dotfiles

WSL2 Ubuntu + Windows host helpers（純 Ubuntu でも Ubuntu 層のみ可）。**Ansible provisions; Stow links configs.**  
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
| herdr, hunk-diff, terminal-browser | [docs/herdr.md](docs/herdr.md) |
| WezTerm (WSL), TB black screen, JP IME | [windows/wezterm/README.md](windows/wezterm/README.md) |
| TB slow on WSL (RAM) | [windows/wsl/README.md](windows/wsl/README.md) |
| Secrets / FAL_KEY / `bws run` | [docs/bws.md](docs/bws.md) (developer section) |
| Logged-in Windows Chrome | skill `agent-browser-win` + [docs/agent-browser-win.md](docs/agent-browser-win.md) |
| LP / genmedia grids | skill `asset-generator` (+ `skills/asset-generator/references/`) |
| Windows host layout | [windows/README.md](windows/README.md) |

## Browser router

| Goal | Tool |
| --- | --- |
| TB on **native Ubuntu** | `Ctrl+B` `Shift+B` → herdr 公式ネスト |
| TB on **WSL** | `Ctrl+B` `Shift+B` / `tb-split` → WezTerm 兄弟ペイン（ネスト禁止） |
| Linux automation | `agent-browser` |
| Win login (Gmail / SSO) | `agent-browser-win` only |

## Edit conventions

- App config → `stow/<name>/` → `./stow.sh restow <name>`
- Pins / `stow_packages` → `ansible/group_vars/all.yml` → `./setup.sh --tags …`
- Ubuntu installers → `scripts/`; Windows+WSL → `windows/`（`scripts/` に Win shim を置かない）
- After herdr config change → `herdr server reload-config`
