# AGENTS.md — inovue/dotfiles

Ubuntu CLI environment for terminal-first web development with coding agents (Claude Code first).
**Ansible provisions; Stow links configs; `managed/` merges into app-owned JSON.**
Human onboarding: [README.md](README.md). Doc index: [docs/README.md](docs/README.md).

## Do not

- Export secrets or `BWS_ACCESS_TOKEN` in shell rc files, or print secret values — use `with-secrets KEY -- cmd` / shims ([docs/bws.md](docs/bws.md))
- Hand-edit or `ln` files in `$HOME` that the repo owns — edit `stow/<pkg>/`, then `./stow.sh restow <pkg>`
- Stow `~/.claude/settings.json` (Claude rewrites it) — edit `managed/*.json`, then `./setup.sh --tags dotfiles`
- Add a tool without a pin + version `check` in `ansible/group_vars/all.yml` (see curl_installer.yml)

## Where things go

| Change | Edit | Apply |
| --- | --- | --- |
| App config (zsh, git, herdr, claude CLAUDE.md/statusline/hooks, …) | `stow/<pkg>/` mirroring `$HOME` | `./stow.sh restow <pkg>` |
| Claude settings keys (hooks, permissions, statusLine) | `managed/*.json` | `./setup.sh --tags dotfiles` |
| Tool versions | `ansible/group_vars/all.yml` | `./setup.sh --tags <role>` |
| New secret-using CLI | shim in `stow/secrets/.local/share/inovue/shims/` | `./stow.sh restow secrets` |
| Installer helpers | `scripts/` | — |

Verify anything with `./doctor.sh`. CI runs shellcheck + ansible syntax (`.github/workflows/lint.yml`).

## Topic map

| Need | Doc |
| --- | --- |
| Layout, roles, pin policy | [docs/architecture.md](docs/architecture.md) |
| `setup.sh`, tags, stow packages | [docs/setup-stow.md](docs/setup-stow.md) |
| Secrets (bws token file, with-secrets, shims, key tiers) | [docs/bws.md](docs/bws.md) |
| herdr, hunk, terminal-browser keys | [docs/herdr.md](docs/herdr.md) |
