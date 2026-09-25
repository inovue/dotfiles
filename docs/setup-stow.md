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

Optional: `./setup.sh --bws-send-url 'https://send.bitwarden.com/#…'` — see [bws.md](bws.md).

## Partial runs

```bash
./setup.sh --tags shell,node
./setup.sh --tags dotfiles
./setup.sh --tags herdr
./setup.sh --tags terminal-browser
./setup.sh --tags agent-browser
```

## Version pins

SSOT: `ansible/group_vars/all.yml`.

1. Bump the pin / version
2. Re-run `./setup.sh` (or matching `--tags`)

## Stow day-to-day

```bash
./stow.sh restow           # all packages in stow/
./stow.sh restow zsh       # one package
./stow.sh unstow herdr
```

### Add a new config package

1. Create `stow/<name>/` mirroring `$HOME`
2. Add `<name>` to `stow_packages` in `ansible/group_vars/all.yml`
3. `./stow.sh restow <name>`

### Conflicts

If Stow refuses because a real file exists, move/remove it then `./stow.sh restow <pkg>`.

## Post-auth

| Tool | Action |
| --- | --- |
| GitHub | `gh auth login` |
| Fly | `fly auth login` |
| Modal | `modal token new` |
| Cursor CLI | `agent login` |
| omp | `omp`（初回ウィザードで provider / model） |
| RTK | `./scripts/setup_rtk.sh` or `./setup.sh --tags tools` |
| terminal-browser | `./setup.sh --tags terminal-browser`（kitty graphics 対応ターミナル） |
| agent-browser | `./setup.sh --tags agent-browser`（[vercel-labs/agent-browser](https://github.com/vercel-labs/agent-browser)；ARM64 は CfT 手動取得、サーバは `--no-sandbox` 既定；公式 skill は `npx skills add … -g`） |
| Bitwarden SM | [bws.md](bws.md) |
| genmedia | `FAL_KEY` in SM, then `genmedia` |
| herdr | [herdr.md](herdr.md) |

## Smoke

```bash
node -v && bun --version && uv --version && gh --version && vips --version
```

## Notes

- Targets **Ubuntu 24.04+** (Ansible asserts). Needs **universe** for packages like `eza` / `libvips-tools` (default on most images; minimal installs: `sudo add-apt-repository universe && sudo apt update`).
- Pin bumps: edit `ansible/group_vars/all.yml`, then re-run setup. Stale pins → 404 → bump the version. Failures are fail-fast — fix network / bump pin and re-run.
