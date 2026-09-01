# dotfiles

WSL2 上の Ubuntu 向けに、モダンな CLI 開発環境を Ansible で一括構築する dotfiles リポジトリです。

## 概要

`setup.yml` を実行すると、zsh をデフォルトシェルにしたうえで、Starship・Sheldon・eza・zoxide・lazygit・GitHub CLI・fnm/Node.js LTS・uv・Modal CLI・flyctl・bws・HyperFrames などをインストールし、`.zshenv` / `.zshrc` などの設定ファイルを配置します。

## 前提条件

- WSL2 + Ubuntu（24.04 想定）
- `sudo` 権限
- Ansible

```bash
sudo apt update
sudo apt install -y ansible
```

`community.general` コレクション（Git 設定用）が必要です。

```bash
ansible-galaxy collection install community.general
```

## セットアップ

リポジトリをクローンして playbook を実行します。

```bash
git clone https://github.com/inovue/dotfiles.git
cd dotfiles
sudo ansible-playbook setup.yml
```

Git のグローバル設定はデフォルトで `SUDO_USER`（`sudo` 実行時の元ユーザー）を使います。上書きする場合:

```bash
sudo ansible-playbook setup.yml \
  -e git_user_name="Your Name" \
  -e git_user_email="you@example.com"
```

完了後、シェルを再読み込みします。

```bash
exec zsh
```

## インストールされる主なツール

| カテゴリ | ツール |
| --- | --- |
| シェル | zsh, Starship, Sheldon（zsh プラグイン管理） |
| ファイル操作 | eza, zoxide, bat, ripgrep, fd-find, fzf |
| Git | lazygit, gh, git-delta |
| ランタイム | fnm + Node.js LTS, uv, Modal CLI |
| その他 | btop, flyctl, bws, HyperFrames（Chrome Headless Shell） |

Sheldon で管理する zsh プラグイン:

- zsh-completions
- zsh-autosuggestions
- zsh-syntax-highlighting

## セットアップ後の確認

HyperFrames の動作確認:

```bash
npx hyperframes doctor
```

WSL から Windows の既定ブラウザで URL を開く `~/.local/bin/wsl-browser` も配置されます（`BROWSER` 環境変数に設定）。

## リポジトリ構成

```
.
├── setup.yml    # Ansible playbook（環境構築の本体）
└── .vscode/     # エディタ設定
```

## ライセンス

個人用 dotfiles です。必要に応じて自由に fork してください。
