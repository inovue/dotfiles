# dotfiles

**Ubuntu**（純 Linux 可）+ 任意で **WSL2 + Windows ホスト連携**。

> Ansible = Ubuntu プロビジョニング、GNU Stow = 設定リンク。Windows 連携は `windows/`。  
> **Agents:** [AGENTS.md](AGENTS.md) · Doc index: [docs/README.md](docs/README.md)

> 22.04 等は apt パッケージ名が合わず失敗する。対象は Ubuntu 24.04 / 26.04。

## セットアップ

```bash
git clone https://github.com/inovue/dotfiles.git
cd dotfiles
./setup.sh
exec zsh   # デフォルトシェル・PATH・zsh 反映（必須）
```

`powershell.exe` がある（典型: WSL2）と Ubuntu 層のあと `windows/setup.sh` も自動実行。純 Ubuntu ではスキップ。

```bash
./setup.sh --ubuntu-only    # Ansible/Stow のみ
./setup.sh --windows-only   # WezTerm + agent-browser-win のみ
```

- 詳細手順・tags・ピン・Stow: [docs/setup-stow.md](docs/setup-stow.md)
- 構成・層分け: [docs/architecture.md](docs/architecture.md)
- Bitwarden Send / SM: [docs/bws.md](docs/bws.md)（`--bws-send-url` または `BWS_SEND_URL` 可）
- Windows 層: [windows/README.md](windows/README.md)
- WSL → Windows Chrome: [docs/agent-browser-win.md](docs/agent-browser-win.md)
- WezTerm（terminal-browser 用 nightly）: [windows/wezterm/README.md](windows/wezterm/README.md)
- herdr + プラグイン: [docs/herdr.md](docs/herdr.md)

Git デフォルト: `user.name` = 実行ユーザー、`user.email` = `{user}@users.noreply.github.com`。上書き例:

```bash
./setup.sh -e git_user_name="Your Name" -e git_user_email="you@example.com"
```

## セットアップ後（認証）

| ツール | アクション |
| --- | --- |
| GitHub / Fly / Modal / Cursor CLI | `gh auth login` / `fly auth login` / `modal token new` / `agent login` |
| Bitwarden SM | [docs/bws.md](docs/bws.md) |
| agent-browser-win | `agent-browser-win start` 後に一度ログイン |
| genmedia | SM に `FAL_KEY` 後 `genmedia` |

```bash
node -v && uv --version && gh --version
npx hyperframes doctor
```

## トラブルシューティング（入口）

| 症状 | 先に見る場所 |
| --- | --- |
| apt / become / Stow 衝突 / ピン更新 | [docs/setup-stow.md](docs/setup-stow.md) |
| terminal-browser 真っ黒（WSL） | [windows/wezterm/README.md](windows/wezterm/README.md) |
| terminal-browser 遅い（WSL RAM / ネスト禁止） | [windows/wsl/README.md](windows/wsl/README.md) · [docs/herdr.md](docs/herdr.md) |
| herdr / hunk / TB キー | [docs/herdr.md](docs/herdr.md) |
| ログイン済みサイト自動化 | [docs/agent-browser-win.md](docs/agent-browser-win.md) |
| ブラウザが開かない（`BROWSER`） | WSL interop + `cmd.exe` on PATH（`wsl-browser`） |

個人用 dotfiles。自由に fork してよい。
