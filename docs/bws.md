# Bitwarden Secrets Manager 運用ガイド

機密情報は Bitwarden SM で一元管理し、ローカルに `.env` を置かず、必要なプロセスにだけ必要な鍵を注入する（`with-secrets` / shim）。

**Agents (daily):** skip admin setup — jump to [日常の開発](#日常の開発) (`with-secrets KEY -- cmd`; never print values). Index: [README.md](README.md).

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
| **`bws run`** | プロジェクトの **全** シークレットを env に注入して実行。広すぎるので通常は `with-secrets` を使う |
| **`with-secrets`** | 指定した鍵だけを注入して実行（`stow/secrets`） |

---

## 全体フロー

```
[管理者]                         [Bitwarden SM]                    [開発者]
   │                                   │                              │
   ├─ シークレット登録・更新 ──────────>│                              │
   ├─ トークン発行 ───────────────────>│                              │
   ├─ Send で URL 共有 ────────────────┼─────────────────────────────>│
   │                                   │<── setup.sh / setup_bws.sh ──┤
   │                                   │   (~/.config/inovue/bws-token)│
   │                                   │<── with-secrets / shim ──────┤
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
with-secrets --check FAL_KEY   # "FAL_KEY: ok (bws)" なら OK
```

`./setup.sh` 実行時に Send URL の入力を促すプロンプトも出る（Enter でスキップ可）。

**方法 2: 単体実行**

`setup.sh` または playbook で bws CLI を導入済みであること。

```bash
./scripts/setup_bws.sh "https://send.bitwarden.com/#XXXXX/YYYYY"
with-secrets --check FAL_KEY
```

トークンは `~/.config/inovue/bws-token` に保存される（600、`setup.sh` 再実行で消えない）。

> 個人の Bitwarden アカウントは不要。トークン設定だけで `bws` が使える。

### 日常の開発

トークンは **どのプロセスの環境変数にも載せない**。`~/.config/inovue/bws-token`（600、トークンのみ）に置き、環境変数には **パスだけ**（`BWS_ACCESS_TOKEN_FILE`、`.zshenv`）を置く。bws を呼ぶ瞬間にだけ読み、その `bws` プロセスにだけ渡す。

| 経路 | 渡るもの | 用途 |
|------|----------|------|
| shim `genmedia` | `FAL_KEY` のみ | そのまま `genmedia ...` |
| shim `bws` | トークン（その `bws` プロセスだけ） | 人間が `bws secret list` 等をそのまま打てる |
| `with-secrets KEY[,KEY] -- cmd` | 指定した鍵のみ（トークンは渡さない） | それ以外のツール・スクリプト |
| fal-skills（falkit ≥ 1.2.0） | 自分で `BWS_ACCESS_TOKEN_FILE` を読む | Claude / どのシェルからでも設定不要で動く |

```bash
with-secrets --check FAL_KEY                       # 値は出さずに有無だけ
with-secrets FAL_KEY -- uv run script.py
with-secrets FAL_KEY,OPENROUTER_API_KEY -- pnpm dev
with-secrets --list                                # 鍵名の一覧
```

- 既に環境変数にある鍵はそちらを優先（プロジェクトの `.env` / direnv で上書き可）。
- `with-secrets KEY -- printenv|env|echo|cat …` は拒否（エージェントの transcript に値が残る事故の防止）。
- shim は `stow/secrets/.local/share/inovue/shims/` に置き、`.zshenv` で PATH 先頭に入る。追加は 3 行:

```sh
#!/bin/sh
exec with-secrets FOO_API_KEY -- foo "$@"
```

- 自作ツールで bws を使うときも `BWS_ACCESS_TOKEN_FILE` を読む（`BWS_ACCESS_TOKEN` を export させない）。
- Claude Code は `managed/claude-settings.json` で `Read/Edit(~/.config/inovue/**)` と `bws secret|run|project` を deny。

> **`genmedia setup` は非推奨** — ローカルに `FAL_KEY` を平文保存するため。

#### 何を守り、何を守らないか

- **守る**: 環境変数ダンプ由来の漏えい（ログ、クラッシュレポート、子プロセスのメタデータ、transcript）。実際に `bws run -- omp` で全鍵を注入していた頃、omp の `~/.omp/run/daemons/*/meta.json` やセッションログに鍵が平文で残っていた。
- **守らない**: 同じユーザーで動く悪意あるコード。しかもこのマシンの `ubuntu` は NOPASSWD sudo なので、エージェント＝root。マシン内の権限分離は効かない。

#### 境界はマシンの外に置く（鍵の階層）

| 階層 | 例 | 置き場所 |
|------|----|----------|
| エージェント用（漏れても被害が小さい） | `FAL_KEY`, `OPENROUTER_API_KEY` | このマシン。専用プロジェクト＋専用マシンアカウント（そのプロジェクトのみ読み取り）、トークン有効期限 90 日、プロバイダ側で利用上限 |
| 強い鍵 | 本番 DB、決済、デプロイトークン | **このマシンに置かない**。Fly secrets / GitHub Actions secrets に直接 |

漏えい時の手順: プロバイダでキー再発行 → SM の値を更新（開発者側の作業なし）→ 旧キー失効。トークン漏えいなら Revoke → 再発行 → `setup_bws.sh`。

## 変更・離脱時

| ケース | 対応 |
|--------|------|
| シークレットの値変更 | ダッシュボードで更新するだけ。開発者側の再設定不要 |
| メンバー離脱・権限変更 | 該当トークンを **Revoke** し、必要なら再発行 |

### トークン再発行（開発者）

`setup.sh` は `~/.config/inovue/bws-token` があると bws 設定をスキップする（旧 `bws.env` は自動で移行）。トークン更新時は以下:

1. 管理者から新しい Send URL を受け取る（旧トークンは Revoke 済みであること）
2. 既存ファイルを削除して再設定:

```bash
rm ~/.config/inovue/bws-token
./scripts/setup_bws.sh "https://send.bitwarden.com/#XXXXX/YYYYY"
with-secrets --check FAL_KEY   # 導通確認
```

`setup.sh --bws-send-url "..."` でも可（事前に `bws-token` を削除すること）。
