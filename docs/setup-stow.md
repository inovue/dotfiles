# Setup, pins, and Stow

Human first-run: [../README.md](../README.md). Layout: [architecture.md](architecture.md).

## Full bootstrap

```bash
git clone https://github.com/inovue/dotfiles.git
cd dotfiles
sudo true
./setup.sh
exec zsh
```

sudo: with passwordless sudo nothing is asked. Otherwise Ansible prompts once for `BECOME password` (your sudo password) — a `sudo` cached in the terminal can't be reused by Ansible's non-interactive sudo.

Optional: `./setup.sh --bws-send-url 'https://send.bitwarden.com/#…'` — see [bws.md](bws.md).

## Partial runs

```bash
./setup.sh --tags shell,node
./setup.sh --tags dotfiles
./setup.sh --tags herdr
./setup.sh --tags terminal-browser
./setup.sh --tags agent-browser
./setup.sh --tags git            # identity from gh (after gh auth login)
./setup.sh --tags docker         # opt-in; never runs in a plain ./setup.sh
```

## Version pins

SSOT: `ansible/group_vars/all.yml`. Policy (exact vs bootstrap): [architecture.md](architecture.md#pin-policy-ansiblegroup_varsallyml).

1. Bump the pin / version
2. Re-run `./setup.sh` (or matching `--tags`) — it reinstalls and verifies `<tool> --version`
3. `./scripts/doctor.sh`

## Stow day-to-day

```bash
./stow.sh restow           # all packages in stow/ (same as ansible)
./stow.sh restow zsh       # one package
./stow.sh unstow herdr
```

### Add a new config package

1. Create `stow/<name>/` mirroring `$HOME` (every directory under `stow/` is linked; no list to update)
2. `./stow.sh restow <name>`

Apps that rewrite their own JSON settings: don't stow — put the keys in `managed/<app>.json` and add it to the loop in `ansible/roles/dotfiles/tasks/main.yml`.

### Conflicts

`stow.sh` moves unmanaged files that block a link to `~/.local/state/inovue/stow-backup/<timestamp>/` and prints each one.

## Post-auth

| Tool | Action |
| --- | --- |
| GitHub | `gh auth login` |
| Fly | `fly auth login` |
| Modal | `modal token new` |
| Claude Code | `claude`（初回起動でログイン；ピンは `claude_code_pin`） |
| gh-workspace | `gh workspace`（ピンは `gh_workspace_pin`、要 `gh auth login`；`shell-init` は v0.1.3 未対応） |
| RTK | `./scripts/setup_rtk.sh` or `./setup.sh --tags tools`（Claude + Cursor hook、hook-only） |
| terminal-browser | `./setup.sh --tags terminal-browser`（kitty graphics 対応ターミナル） |
| agent-browser | `./setup.sh --tags agent-browser`（[vercel-labs/agent-browser](https://github.com/vercel-labs/agent-browser)；ARM64 は CfT 手動取得、サーバは `--no-sandbox` 既定；公式 skill は `npx skills add … -g`） |
| Bitwarden SM | [bws.md](bws.md) |
| genmedia | `FAL_KEY` in SM, then `genmedia` |
| herdr | [herdr.md](herdr.md) |

## Smoke

```bash
./scripts/doctor.sh
```

## Notes

- Targets **Ubuntu 24.04+** (Ansible asserts). Needs **universe** for packages like `eza` / `libvips-tools` (default on most images; minimal installs: `sudo add-apt-repository universe && sudo apt update`).
- Pin bumps: edit `ansible/group_vars/all.yml`, then re-run setup. Stale pins → 404 → bump the version. Failures are fail-fast — fix network / bump pin and re-run.
