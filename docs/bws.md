# Bitwarden Secrets Manager 運用ガイド

機密情報は Bitwarden SM で一元管理し、ローカルに `.env` を置かず `bws` で注入する。

---

## Bitwarden リソース構成

ダッシュボード上の名前は以下に統一する。

| 種別 | 名前 | 役割 |
|------|------|------|
| プロジェクト | `inovue-local-dev` | ローカル開発用シークレットのスコープ |
| マシンアカウント | `inovue-workstation` | 開発者端末（bws CLI）のアクセス主体 |

**初回セットアップ（管理者）**

1. **Projects** → `inovue-local-dev` を作成
2. **Machine accounts** → `inovue-workstation` を作成
3. `inovue-workstation` に `inovue-local-dev` へのアクセス権（読み取り）を付与
4. シークレットを `inovue-local-dev` に登録（例: `FAL_KEY` — genmedia 用）

**将来の拡張例**

| 用途 | プロジェクト | マシンアカウント |
|------|-------------|-----------------|
| GitHub Actions | `inovue-local-dev` または `inovue-ci` | `inovue-github-actions` |
| 本番 | `inovue-production` | デプロイ先名（例: `inovue-fly`） |

---

## 用語

| 用語 | 説明 |
|------|------|
| **シークレット** | API キー、DB 接続文字列など Key/Value で管理する機密データ |
| **プロジェクト** | シークレットをまとめる単位。権限もプロジェクト単位（`inovue-local-dev`） |
| **マシンアカウント** | 人ではなく開発環境・CI 用のアカウント（`inovue-workstation`） |
| **アクセストークン** | マシンアカウントの認証キー（`0.xxxx...`）。`BWS_ACCESS_TOKEN` に設定 |
| **Bitwarden Send** | 期限・閲覧回数付きの一時共有リンク。トークン送付に使う |
| **`bws`** | SM 公式 CLI |
| **`bws run`** | 実行時のみメモリ上に環境変数を注入してコマンドを実行 |

---

## 全体フロー

```
[管理者]                         [Bitwarden SM]                    [開発者]
   │                                   │                              │
   ├─ シークレット登録・更新 ──────────>│                              │
   ├─ トークン発行 ───────────────────>│                              │
   ├─ Send で URL 共有 ────────────────┼─────────────────────────────>│
   │                                   │<── setup.sh / setup_bws.sh ──┤
   │                                   │    (~/.config/inovue/bws.env)│
   │                                   │<── bws run で開発・実行 ─────┤
```

---

## 管理者

新規メンバー参画時、またはシークレット追加・更新時に実施。

### 1. シークレットの登録・更新

1. [vault.bitwarden.com](https://vault.bitwarden.com) → **Secrets Manager** → **Secrets**
2. プロジェクト `inovue-local-dev` に割り当てられていることを確認

### 2. トークン発行

1. **Machine accounts** → `inovue-workstation` を開く
2. `inovue-local-dev` への読み取り権限を確認
3. **Create access token** でトークンを生成

### 3. トークン共有

Bitwarden Password Manager で **Send** を作成:

| 項目 | 値 |
|------|-----|
| テキスト | 発行したトークン |
| 最大閲覧回数 | 1 回 |
| 有効期限 | 1 時間〜1 日 |

Send URL を Slack 等で対象メンバーに送る。

---

## 開発者

### 初回セットアップ

**方法 1: `setup.sh` に統合（推奨）**

Send URL を管理者から受け取ったら:

```bash
./setup.sh --bws-send-url "https://send.bitwarden.com/#XXXXX/YYYYY"
exec zsh
bws secret list   # 一覧が表示されれば OK
```

`./setup.sh` 実行時に Send URL の入力を促すプロンプトも出る（Enter でスキップ可）。

**方法 2: 単体実行**

`setup.sh` または playbook で bws CLI を導入済みであること。

```bash
./scripts/setup_bws.sh "https://send.bitwarden.com/#XXXXX/YYYYY"
exec zsh
bws secret list
```

トークンは `~/.config/inovue/bws.env` に保存される（`setup.sh` 再実行で消えない）。

> 個人の Bitwarden アカウントは不要。トークン設定だけで `bws` が使える。

### 日常の開発

`.env` は置かず、`bws run` で実行する。bws 経由のエイリアスは `.zshenv` に定義（`playbook.yml` で管理）。

```bash
bws run -- "npm run dev"
bws run -- "python main.py"
genmedia --help   # alias 経由。FAL_KEY は SM から注入
```

> **`genmedia setup` は非推奨** — ローカルに `FAL_KEY` を平文保存するため。SM に `FAL_KEY` を登録し、`genmedia` エイリアス（`bws run -- genmedia`）を使う。

エイリアス追加例（`playbook.yml` の `.zshenv` セクション）:

```zsh
alias foo='bws run -- foo'
```

---

## 変更・離脱時

| ケース | 対応 |
|--------|------|
| シークレットの値変更 | ダッシュボードで更新するだけ。開発者側の再設定不要 |
| メンバー離脱・権限変更 | 該当トークンを **Revoke** し、必要なら再発行 |

### トークン再発行（開発者）

`setup.sh` は `~/.config/inovue/bws.env` があると bws 設定をスキップする。トークン更新時は以下:

1. 管理者から新しい Send URL を受け取る（旧トークンは Revoke 済みであること）
2. 既存ファイルを削除して再設定:

```bash
rm ~/.config/inovue/bws.env
./scripts/setup_bws.sh "https://send.bitwarden.com/#XXXXX/YYYYY"
exec zsh
bws secret list   # 導通確認
```

`setup.sh --bws-send-url "..."` でも可（事前に `bws.env` を削除すること）。
