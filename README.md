# dotfiles

WSL2 + **Ubuntu 24.04** 向け CLI 開発環境を Ansible で一括構築する。

> 22.04 等は playbook 内の apt パッケージ名が合わず失敗する。24.04 以外は未検証。

## セットアップ

```bash
git clone https://github.com/inovue/dotfiles.git
cd dotfiles
./setup.sh
exec zsh   # デフォルトシェル変更・PATH・zsh 設定を反映（必須）
```

Send URL がある場合は `./setup.sh --bws-send-url "https://send.bitwarden.com/#..."` も可。

- `setup.sh` — Ansible / `community.general` を未導入なら入れてから playbook を実行。末尾で bws トークン設定も可能
- 再実行可（冪等）。ネットワーク必須
- Git デフォルト: `user.name` = `SUDO_USER`、`user.email` = `{user}@users.noreply.github.com`

```bash
./setup.sh \
  -e git_user_name="Your Name" \
  -e git_user_email="you@example.com"
```

Bitwarden Send URL は `--bws-send-url`、環境変数 `BWS_SEND_URL`、または対話プロンプトで渡せる。詳細は [docs/bws.md](docs/bws.md)。

WSL 上では続けて [docs/agent-browser-win.md](docs/agent-browser-win.md) のブリッジ（Windows Chrome 専用プロファイル + agent-browser）もセットアップする。単体実行は `./scripts/setup_agent_browser_win.sh`。

手動: `sudo ansible-playbook playbook.yml`（`-e` も同様に渡せる。bws トークン設定は `./scripts/setup_bws.sh`、Windows Chrome ブリッジは `./scripts/setup_agent_browser_win.sh` で別途）

## インストール内容

| カテゴリ | ツール |
| --- | --- |
| シェル | zsh, Starship, Sheldon (+ completions / autosuggestions / syntax-highlighting), herdr |
| ファイル操作 | eza, zoxide, bat, ripgrep, fd-find, fzf, btop |
| Git | lazygit, gh, git-delta, hunk (hunkdiff) |
| ランタイム | fnm + Node.js LTS, bun, pnpm, uv, Modal CLI |
| AI / デプロイ | genmedia, Cursor CLI (`agent`), agent-browser（Linux）+ agent-browser-win（WSL→Windows Chrome） |
| インフラ | flyctl, bws |
| メディア | HyperFrames, ffmpeg, libvips, Noto CJK フォント |

`.zshenv` / `.zshrc` / `starship.toml` / `sheldon/plugins.toml` を配置。WSL では `wsl-browser` を `BROWSER` に設定（`cmd.exe` interop 前提）。

## セットアップ後

使うツールだけ認証・初期設定を行う。

| ツール | コマンド |
| --- | --- |
| GitHub CLI | `gh auth login` |
| Fly.io | `fly auth login` |
| Modal | `modal token new` |
| Bitwarden SM | [docs/bws.md](docs/bws.md) — `setup.sh` 時に未設定なら `./scripts/setup_bws.sh` |
| Windows Chrome (agent-browser-win) | [docs/agent-browser-win.md](docs/agent-browser-win.md) — `setup.sh` 後に `agent-browser-win start` で一度ログイン |
| genmedia | SM に `FAL_KEY` 登録後 `genmedia`（bws 設定済みが前提） |
| Cursor CLI | `agent login` |

```bash
node -v && uv --version && gh --version
npx hyperframes doctor
```

## トラブルシューティング

| 症状 | 対処 |
| --- | --- |
| apt / パッケージ名エラー | Ubuntu 24.04 か確認 |
| Sheldon / lazygit / bws の取得失敗 | GitHub API rate limit — 時間をおいて `./setup.sh` を再実行 |
| `node` / エイリアスが効かない | `exec zsh` または新しいターミナル |
| ブラウザが開かない | WSL interop 有効化、`cmd.exe` が PATH にあるか確認 |
| ログイン済みサイトを自動化できない | [docs/agent-browser-win.md](docs/agent-browser-win.md) — `agent-browser-win` を使う（普段の Chrome プロファイルは不可） |

個人用 dotfiles。自由に fork してよい。
