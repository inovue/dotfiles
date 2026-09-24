# dotfiles

Ubuntu 向け CLI 環境（サーバ開発向け）。Ansible でプロビジョニング、GNU Stow で設定リンク。

> 対象: Ubuntu 24.04 / 26.04。  
> **Agents:** [AGENTS.md](AGENTS.md) · Doc index: [docs/README.md](docs/README.md)

## セットアップ

```bash
git clone https://github.com/inovue/dotfiles.git
cd dotfiles
./setup.sh
exec zsh
```

- 詳細・tags・ピン・Stow: [docs/setup-stow.md](docs/setup-stow.md)
- 構成: [docs/architecture.md](docs/architecture.md)
- Bitwarden SM: [docs/bws.md](docs/bws.md)（`--bws-send-url` または `BWS_SEND_URL`）
- herdr: [docs/herdr.md](docs/herdr.md)

Git デフォルト: `user.name` = 実行ユーザー、`user.email` = `{user}@users.noreply.github.com`。上書き例:

```bash
./setup.sh -e git_user_name="Your Name" -e git_user_email="you@example.com"
```

## セットアップ後（認証）

| ツール | アクション |
| --- | --- |
| GitHub / Fly / Modal / Cursor CLI | `gh auth login` / `fly auth login` / `modal token new` / `agent login` |
| Bitwarden SM | [docs/bws.md](docs/bws.md) |
| genmedia | SM に `FAL_KEY` 後 `genmedia` |

## トラブルシューティング

| 症状 | 先に見る場所 |
| --- | --- |
| apt / become / Stow 衝突 / ピン更新 | [docs/setup-stow.md](docs/setup-stow.md) |
| herdr / hunk キー | [docs/herdr.md](docs/herdr.md) |

個人用 dotfiles。自由に fork してよい。
