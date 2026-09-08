# dotfiles

WSL2 + **Ubuntu 24.04 / 26.04** 向け CLI 開発環境。

> Ansible = プロビジョニング、GNU Stow = 設定リンク。日常の設定変更は `stow/` を編集して `./stow.sh restow`。  
> **Agents:** [AGENTS.md](AGENTS.md) · Doc index: [docs/README.md](docs/README.md)

> 22.04 等は apt パッケージ名が合わず失敗する。

## セットアップ

```bash
git clone https://github.com/inovue/dotfiles.git
cd dotfiles
./setup.sh
exec zsh   # デフォルトシェル・PATH・zsh 反映（必須）
```

- 詳細手順・tags・ピン・Stow: [docs/setup-stow.md](docs/setup-stow.md)
- 構成: [docs/architecture.md](docs/architecture.md)
- Bitwarden Send / SM: [docs/bws.md](docs/bws.md)（`--bws-send-url` または `BWS_SEND_URL` 可）
- WSL → Windows Chrome: [docs/agent-browser-win.md](docs/agent-browser-win.md)（`./scripts/setup_agent_browser_win.sh`）
- WezTerm（terminal-browser 用 nightly）: [windows/wezterm/README.md](windows/wezterm/README.md) — `./windows/wezterm/setup.sh`
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
| terminal-browser 真っ黒 | [windows/wezterm/README.md](windows/wezterm/README.md) |
| herdr / hunk / TB キー | [docs/herdr.md](docs/herdr.md) |
| ログイン済みサイト自動化 | [docs/agent-browser-win.md](docs/agent-browser-win.md) |
| ブラウザが開かない（`BROWSER`） | WSL interop + `cmd.exe` on PATH（`wsl-browser`） |

個人用 dotfiles。自由に fork してよい。
