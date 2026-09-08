# Windows host configs (WSL2 + Windows)

Ubuntu 層（`ansible/` / `stow/` / ルート `./setup.sh`）とは別に、**Windows ホスト連携**はここに置く。  
Repo map: [../AGENTS.md](../AGENTS.md) · [../docs/README.md](../docs/README.md)。

| パス | 役割 |
| --- | --- |
| `setup.sh` | **一括入口** — `.wslconfig` + agent-browser-win + WezTerm |
| `wsl/` | `%USERPROFILE%\.wslconfig`（TB/agents 用 RAM・CPU） |
| `agent-browser-win/` | WSL→Windows Chrome ブリッジ |
| `wezterm/` | WezTerm nightly / lua / フォント |

## なぜ分けるか

- Stow は Linux `$HOME` をミラーする。Windows の `%USERPROFILE%` は対象外
- Ansible は Ubuntu プロビジョニング用。winget / GUI 設定は別ライフサイクル
- WSL から「同期・診断」する入口だけ bash、実体の Windows 操作は `.ps1`

## セットアップ

ルート `./setup.sh` が `powershell.exe` を検出すると自動でここを実行する。

```bash
./setup.sh                 # Ubuntu +（WSLなら）Windows
./setup.sh --ubuntu-only   # Ansible/Stow のみ
./setup.sh --windows-only  # この層のみ
./windows/setup.sh         # 同上（Windows 層の直接入口）
```

個別:

```bash
./windows/wsl/setup.sh
./windows/agent-browser-win/setup.sh
./windows/wezterm/setup.sh
./windows/wsl/doctor.sh
./windows/wezterm/doctor.sh
```

`.wslconfig` 変更後は Windows で `wsl --shutdown` が必要（[wsl/README.md](wsl/README.md)）。

詳細: [wsl](wsl/README.md) · [agent-browser-win](../docs/agent-browser-win.md) · [wezterm/README.md](wezterm/README.md)
