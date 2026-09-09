# Setup, pins, and Stow

Human first-run: [../README.md](../README.md). Layout: [architecture.md](architecture.md).

## Full bootstrap

```bash
git clone https://github.com/inovue/dotfiles.git
cd dotfiles
sudo true                    # become cache for apt
./setup.sh
exec zsh                     # required: shell + PATH
```

Optional: `./setup.sh --bws-send-url 'https://send.bitwarden.com/#…'` — see [bws.md](bws.md).

On WSL (`powershell.exe` present), setup also runs `./windows/setup.sh` (`.wslconfig` + agent-browser-win + WezTerm).  
Overrides: `--ubuntu-only` / `--windows-only` — see [architecture.md](architecture.md).

## Partial runs

```bash
./setup.sh --tags shell,node
./setup.sh --tags dotfiles
./setup.sh --tags herdr
./setup.sh --tags terminal-browser
./setup.sh --ubuntu-only --tags dotfiles
./setup.sh --windows-only
```

Manual playbook:

```bash
sudo true
ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook -i ansible/inventory ansible/site.yml
```

## Version pins

SSOT: `ansible/group_vars/all.yml`.

1. Bump the pin / version variable
2. Re-run `./setup.sh` (or matching `--tags`)
3. Official install-script tools stamp `~/.config/inovue/tool-pins/`

No GitHub “latest” auto-follow.

## Stow day-to-day

```bash
./stow.sh restow           # all packages in stow/
./stow.sh restow zsh       # one package
./stow.sh unstow herdr
```

`stow` must be installed (`./setup.sh` or `apt install stow`).

### Add a new config package

1. Create `stow/<name>/` with paths as they appear under `$HOME`
2. Add `<name>` to `stow_packages` in `ansible/group_vars/all.yml`
3. `./stow.sh restow <name>` (or full setup with `dotfiles` tag)

### Conflicts

If Stow refuses because a real file already exists, move/remove the conflict then `./stow.sh restow <pkg>`.

## Post-auth checklist

| Tool | Action |
| --- | --- |
| GitHub | `gh auth login` |
| Fly | `fly auth login` |
| Modal | `modal token new` |
| Cursor CLI | `agent login` |
| RTK (Cursor global) | `./scripts/setup_rtk.sh` or `./setup.sh --tags tools` — then restart Cursor CLI |
| Bitwarden SM | [bws.md](bws.md) |
| agent-browser-win | [agent-browser-win.md](agent-browser-win.md) — `start` then log in once |
| genmedia | `FAL_KEY` in SM, then `genmedia` |
| herdr / TB | [herdr.md](herdr.md); WezTerm: [../windows/wezterm/README.md](../windows/wezterm/README.md) |

## Smoke

```bash
node -v && bun --version && uv --version && gh --version
npx hyperframes doctor
./windows/wezterm/doctor.sh    # if using TB on Windows WezTerm
```
