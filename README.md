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

- `setup.sh` — Ansible / `community.general` を未導入なら入れてから playbook を実行
- 再実行可（冪等）。ネットワーク必須
- Git デフォルト: `user.name` = `SUDO_USER`、`user.email` = `{user}@users.noreply.github.com`

```bash
./setup.sh \
  -e git_user_name="Your Name" \
  -e git_user_email="you@example.com"
```

手動: `sudo ansible-playbook playbook.yml`（`-e` も同様に渡せる）

## インストール内容

| カテゴリ | ツール |
| --- | --- |
| シェル | zsh, Starship, Sheldon (+ completions / autosuggestions / syntax-highlighting) |
| ファイル操作 | eza, zoxide, bat, ripgrep, fd-find, fzf, btop |
| Git | lazygit, gh, git-delta, hunk (hunkdiff) |
| ランタイム | fnm + Node.js LTS, bun, uv, Modal CLI |
| AI / デプロイ | genmedia, Cursor CLI (`agent`) |
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
| Bitwarden SM | `export BWS_ACCESS_TOKEN=...` |
| genmedia | `genmedia setup` または `export FAL_KEY=...` |
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

個人用 dotfiles。自由に fork してよい。
