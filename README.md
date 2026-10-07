# dotfiles

Ubuntu 向けのターミナル中心 web 開発環境（Claude Code 主体）。Ansible でプロビジョニング、GNU Stow で設定リンク、シークレットは Bitwarden SM から必要な鍵だけ注入。

> 対象: Ubuntu 24.04 / 26.04。  
> **Agents:** [AGENTS.md](AGENTS.md) · Doc index: [docs/README.md](docs/README.md)

## セットアップ

```bash
git clone https://github.com/inovue/dotfiles.git
cd dotfiles
./setup.sh
exec zsh
./doctor.sh
```

- 詳細・tags・ピン・Stow: [docs/setup-stow.md](docs/setup-stow.md)
- 構成: [docs/architecture.md](docs/architecture.md)
- Bitwarden SM: [docs/bws.md](docs/bws.md)（`--bws-send-url` または `BWS_SEND_URL`）
- herdr: [docs/herdr.md](docs/herdr.md)

Git の identity は `gh auth login` 後に `./setup.sh --tags git` で GitHub アカウント（`<id>+<login>@users.noreply.github.com`）から設定される。明示する場合:

```bash
./setup.sh --tags git -e git_user_name="Your Name" -e git_user_email="you@example.com"
```

## セットアップ後（認証）

| ツール | アクション |
| --- | --- |
| GitHub / Fly / Modal | `gh auth login`（→ `./setup.sh --tags git`）/ `fly auth login` / `modal token new` |
| Cloudflare / Slack / GCP | `wrangler login` / `slack login` / `gcloud auth login` |
| Bitwarden SM | [docs/bws.md](docs/bws.md) |
| genmedia / その他 API キー | SM に登録 → `genmedia` はそのまま、他は `with-secrets KEY -- cmd` |

## トラブルシューティング

| 症状 | 先に見る場所 |
| --- | --- |
| apt / become / Stow 衝突 / ピン更新 | [docs/setup-stow.md](docs/setup-stow.md) |
| herdr / hunk キー | [docs/herdr.md](docs/herdr.md) |

個人用 dotfiles。自由に fork してよい。
