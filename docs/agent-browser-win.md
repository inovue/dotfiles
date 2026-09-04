# WSL から Windows Chrome（専用プロファイル）を agent-browser で操作する

対象環境: **WSL2 (Ubuntu) + Windows 11 + Cursor / Cursor CLI**

普段使いの Chrome プロファイルは Chrome 136+ の制限で CDP 自動化に使えない。  
代わりに専用プロファイルを用意し、**Windows 側の agent-browser** 経由で操作する。

## なぜこの形か

| やり方 | 結果 |
|--------|------|
| WSL の agent-browser が Linux Chrome で Windows `User Data` を開く | 起動できてもログイン Cookie を復号できない |
| WSL から `connect 9222`（Windows Chrome CDP） | WSL2 NAT では Windows `127.0.0.1` に届かない |
| デフォルト `User Data` + `--remote-debugging-port` | Chrome 136+ が無視する |
| **専用 `user-data-dir` + Windows agent-browser** | CDP 可・ログイン永続（推奨） |

## セットアップ

dotfiles の `./setup.sh` が自動で行う（または単体実行）:

```bash
./scripts/setup_agent_browser_win.sh
```

実施内容:

1. `~/.local/bin/agent-browser-win` をリンク
2. ヘルパー PS1 を `%LOCALAPPDATA%\agent-browser-win\` に同期
3. Windows に Node（無ければ winget）+ `npm i -g agent-browser`
4. Cursor skill `agent-browser-win` を `~/.cursor/skills` と `~/.agents/skills` に配置

前提:

- WSL interop で `powershell.exe` が使えること
- Windows に Google Chrome が入っていること

## 初回ログイン

```bash
agent-browser-win start
# 開いた Chrome で Google 等にログイン
agent-browser-win open https://mail.google.com
agent-browser-win get title
```

プロファイル実体: `%LOCALAPPDATA%\Google\Chrome\AgentBrowserProfile`  
（通常の Chrome と同時起動可）

## 日常操作

```bash
agent-browser-win start          # CDP 付き専用 Chrome
agent-browser-win status
agent-browser-win doctor
agent-browser-win open https://example.com
agent-browser-win snapshot -i
agent-browser-win stop           # 専用 Chrome だけ終了
```

任意の agent-browser サブコマンドをそのまま渡せる（`start`/`stop`/`status`/`doctor` 以外）。

## 環境変数（任意）

| 変数 | 既定 | 意味 |
|------|------|------|
| `AGENT_BROWSER_WIN_PROFILE` | `AgentBrowserProfile` | プロファイルフォルダ名 |
| `AGENT_BROWSER_WIN_CDP_PORT` | `9222` | CDP ポート |
| `AGENT_BROWSER_WIN_SESSION` | `win-agent-profile` | agent-browser セッション名（裸の `AGENT_BROWSER_SESSION` は無視） |

ユーザー名入りの絶対パスはスクリプトに埋め込まない。Windows 側は `%LOCALAPPDATA%` / `%USERPROFILE%` を使う。

## Cursor / Agent 向け

Skill: `agent-browser-win`（セットアップでインストール）。  
ブラウザ操作が必要でログイン状態が要るときは、Linux 直起動ではなく `agent-browser-win` を使う。

## トラブルシュート

| 症状 | 対処 |
|------|------|
| `powershell.exe not found` | WSL interop を有効化 |
| `chrome: NOT FOUND` | Windows に Google Chrome を入れる |
| `agent-browser: NOT FOUND` | `./scripts/setup_agent_browser_win.sh` 再実行 |
| `Daemon version mismatch` / ハング | `agent-browser-win stop` 後に `start`。`AGENT_BROWSER_SESSION` が Linux 実験用の値なら unset。ダメなら `%USERPROFILE%\.agent-browser` の該当セッションファイルを削除 |
| CDP down | `agent-browser-win start` |
| `CDP is up but owned by ...` / FOREIGN | 別プロセスがポートを占有。`AGENT_BROWSER_WIN_CDP_PORT` を空きポートに変更 |
| `Timed out waiting for ... lock` | 別の `agent-browser-win` が実行中／固着。終わるのを待つか `stop` |
| 未ログイン | `start` で開いたウィンドウで再ログイン（コピーやジャンクションでは Cookie が壊れる） |
| `python3: not found` | WSL に python3 を入れる（引数 JSON エンコードに使用） |
| 環境変数が効かない | ラッパー経由で呼ぶこと（`AGENT_BROWSER_WIN_*` は sh が PS へ転送）。PS1 直呼びなら Windows 側で `$env:...` を設定 |
| `Invalid AGENT_BROWSER_WIN_PROFILE` | 8文字以上・パス禁則文字なし・Chrome 予約名（`Default` 等）以外 |

## 安定化の仕組み（実装済み）

- **CDP 所有者検証**: HTTP 応答だけでなく、listen PID の cmdline が `--user-data-dir=<専用プロファイル>` かつ `--remote-debugging-port=<設定ポート>` かを確認。他人の CDP を「起動済み」と誤認しない
- **mutex**: `Local\AgentBrowserWin_<profile>_<port>` で同一プロファイル＋ポートの並列呼び出しを直列化（最大 120 秒待機）
- **プロファイル照合**: フォルダ名の部分一致ではなく `--user-data-dir` のフルパス一致
- **セッション限定 daemon reset**: 他プロファイル用の `agent-browser` プロセスを巻き込み殺さない
- **SingletonLock 掃除**: CDP 無しでプロファイルが残ロックだけのとき起動前に除去
- **プロファイル名バリデーション**: 短すぎる名前／予約名を拒否

## プラットフォーム上の制約（塞げない）

- 普段使いの Chrome `User Data` は Chrome 136+ が CDP を拒否する → 専用プロファイル必須
- WSL2 NAT では Windows の `127.0.0.1` に届かない → Windows 側 agent-browser 経由が必須（mirrored networking でもブリッジ推奨）
- プロファイルのファイルコピー／ジャンクションでは App-Bound Encryption によりログインが壊れる

## 関連ファイル

- `scripts/agent-browser-win.sh` — WSL 入口
- `scripts/agent-browser-win.ps1` — Windows 実装
- `scripts/setup_agent_browser_win.sh` — セットアップ
- `skills/agent-browser-win/SKILL.md` — Cursor skill ソース
