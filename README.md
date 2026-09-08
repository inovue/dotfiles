# dotfiles

WSL2 + **Ubuntu 24.04 / 26.04** 向け CLI 開発環境。

> **モダン方針:** Ansible = プロビジョニング（パッケージ・ピン・システム状態）、GNU Stow = 設定のシンボリックリンク。設定変更は `stow/` を編集して `./stow.sh restow`（フルセットアップは不要）。

> 22.04 等は apt パッケージ名が合わず失敗する。

## セットアップ

```bash
git clone https://github.com/inovue/dotfiles.git
cd dotfiles
./setup.sh
exec zsh   # デフォルトシェル変更・PATH・zsh 設定を反映（必須）
```

Send URL がある場合は `./setup.sh --bws-send-url "https://send.bitwarden.com/#..."` も可。

- `setup.sh` — Ansible 未導入なら入れてから `ansible/site.yml` を実行（ユーザー権限。`become` 用に先に `sudo true`）。末尾で bws トークン設定も可能
- 再実行可（冪等）。ネットワーク必須
- Git デフォルト: `user.name` = 実行ユーザー、`user.email` = `{user}@users.noreply.github.com`

```bash
./setup.sh \
  -e git_user_name="Your Name" \
  -e git_user_email="you@example.com"
```

Bitwarden Send URL は `--bws-send-url`、環境変数 `BWS_SEND_URL`、または対話プロンプトで渡せる。詳細は [docs/bws.md](docs/bws.md)。

WSL 上では続けて [docs/agent-browser-win.md](docs/agent-browser-win.md) のブリッジもセットアップする。単体実行は `./scripts/setup_agent_browser_win.sh`。

**Windows ホスト設定**（WezTerm など）は Ansible/Stow とは別の [`windows/`](windows/README.md)。terminal-browser 表示には WezTerm **nightly** が必要: `./windows/wezterm/setup.sh`。

手動:

```bash
sudo true
ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook -i ansible/inventory ansible/site.yml
```

部分実行例: `./setup.sh --tags shell,node` / `./setup.sh --tags dotfiles`

## リポジトリ構成

```
stow/                 # 設定のみ（1 アプリ = 1 パッケージ、$HOME をミラー）
  zsh/ .zshenv .zshrc
  starship/ .config/starship.toml
  sheldon/ helix/ herdr/ hunk/ bin/
  cursor/ .cursor/statusline.sh   # cli-config.json は認証込みのため Stow せず Ansible が statusLine だけ注入
ansible/              # プロビジョニングのみ
  site.yml            # 薄いプレイブック
  group_vars/all.yml  # バージョンピン・stow_packages
  roles/              # base | shell | node | tools | dotfiles
scripts/ docs/ skills/
setup.sh              # フルブートストラップ
stow.sh               # 日常の link / unlink / restow
```

### 設定だけ更新

```bash
./stow.sh restow           # 全パッケージ
./stow.sh restow zsh       # 1 パッケージ
./stow.sh unstow herdr     # リンク解除
```

新しいツール設定を足すとき: `stow/<name>/` に `$HOME` 相対パスで置き、`ansible/group_vars/all.yml` の `stow_packages` に追加して `./stow.sh restow <name>`。

## インストール内容

| カテゴリ | ツール |
| --- | --- |
| シェル | zsh, Starship, Sheldon (+ completions / autosuggestions / syntax-highlighting), herdr (+ herdr-hunk-diff, terminal-browser), Helix |
| ファイル操作 | eza, zoxide, bat, ripgrep, fd-find, fzf, btop |
| Git | lazygit, gh, git-delta, hunk (hunkdiff) |
| ランタイム | fnm + Node.js LTS, pnpm, uv, Modal CLI |
| AI / デプロイ | genmedia, Cursor CLI (`agent`), agent-browser（Linux Chrome for Testing）+ HyperFrames（別途 Headless Shell）+ agent-browser-win（WSL→Windows Chrome）, asset-generator skill（`~/.cursor/skills`） |
| インフラ | flyctl, bws |
| メディア | HyperFrames, ffmpeg, Noto CJK フォント |

WSL では `wsl-browser`（`stow/bin`）を `BROWSER` に設定（`cmd.exe` interop 前提）。

### ピン留めバージョン

`ansible/group_vars/all.yml` の値を上げて `./setup.sh`（または該当 tags）を再実行。

- GitHub リリース直置き: `sheldon_version` / `lazygit_version` / `bws_version` / `helix_version`
- 公式 install スクリプト: `starship_pin` / `zoxide_pin` / `fnm_pin` / `uv_pin` / `flyctl_pin` / `herdr_pin` / `herdr_hunkdiff_pin` / `terminal_browser_pin` / `herdr_terminal_browser_pin` / `pnpm_pin` / `genmedia_pin` / `cursor_agent_pin`（`~/.config/inovue/tool-pins/`）

GitHub API の latest 自動追従はしない。

## セットアップ後

| ツール | コマンド |
| --- | --- |
| GitHub CLI | `gh auth login` |
| Fly.io | `fly auth login` |
| Modal | `modal token new` |
| Bitwarden SM | [docs/bws.md](docs/bws.md) |
| Windows Chrome (agent-browser-win) | [docs/agent-browser-win.md](docs/agent-browser-win.md) — `agent-browser-win start` で一度ログイン |
| genmedia | SM に `FAL_KEY` 登録後 `genmedia` |
| Cursor CLI | `agent login` |
| herdr-hunk-diff | `Ctrl+B Shift+H` でレビュー、`Ctrl+B Shift+S` でコメント送信。エージェント idle 時は自動オープン |
| terminal-browser | `Ctrl+B Shift+B` で右スプリットに開く（herdr プラグイン）。Kitty graphics 対応ターミナルが必要 |

```bash
node -v && uv --version && gh --version
npx hyperframes doctor
```

## トラブルシューティング

| 症状 | 対処 |
| --- | --- |
| apt / パッケージ名エラー | Ubuntu 24.04 または 26.04 か確認 |
| `become` / sudo 失敗 | `sudo true` してから再実行 |
| Stow が既存ファイルで失敗 | `./stow.sh restow`（衝突する実ファイルはクリアしてから link） |
| Sheldon / lazygit / bws / Helix の更新 | `ansible/group_vars/all.yml` のピンを上げて `./setup.sh` |
| `node` / エイリアスが効かない | `exec zsh` または新しいターミナル |
| ブラウザが開かない | WSL interop 有効化、`cmd.exe` が PATH にあるか確認 |
| terminal-browser が WezTerm で真っ黒／何も出ない | `./windows/wezterm/setup.sh`（winget nightly）→ WezTerm 再起動 → `./windows/wezterm/doctor.sh`。Windows Terminal / Cursor 内蔵端末では描画されない。[windows/wezterm/README.md](windows/wezterm/README.md) |
| ログイン済みサイトを自動化できない | [docs/agent-browser-win.md](docs/agent-browser-win.md) |

個人用 dotfiles。自由に fork してよい。
