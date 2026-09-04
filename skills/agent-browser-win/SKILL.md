---
name: agent-browser-win
description: >-
  Drive a logged-in Windows Chrome from WSL/Cursor via a dedicated CDP profile
  (agent-browser-win). Use when automating browsers that need real login state
  on WSL2+Windows11, or when Linux agent-browser profile reuse fails.
---

# agent-browser-win

WSL2 (Ubuntu) + Windows 11 + Cursor 向け。ログイン済み Windows Chrome を操作するときは **Linux の agent-browser 直起動ではなく** このラッパーを使う。

## When to use

- Gmail / Google / 社内 SSO など **実ログイン状態** が必要
- ユーザーが WSL 上の Cursor / Cursor CLI からブラウザ操作を依頼した
- 素の `agent-browser --profile` で Windows の普段プロファイルを使う提案をしそうなとき（それは失敗する）

## Do this

```bash
agent-browser-win start          # 未起動なら専用 Chrome + CDP
agent-browser-win open <url>
agent-browser-win snapshot -i
# 操作後
agent-browser-win stop           # 専用 Chrome だけ止める（任意）
```

状態確認:

```bash
agent-browser-win status
agent-browser-win doctor
```

セットアップ未実施や壊れたとき:

```bash
# from dotfiles repo
./scripts/setup_agent_browser_win.sh
```

詳細・制約・トラブルシュート: リポジトリの `docs/agent-browser-win.md`。

## Do not

- WSL から `agent-browser connect 9222` / `--cdp 9222` を **Windows Chrome に直接** 叩かない（WSL2 NAT で届かない）
- Linux Chrome に Windows の `%LOCALAPPDATA%\Google\Chrome\User Data` を `--profile` しない（Cookie 復号不可）
- 普段の Chrome を `--remote-debugging-port` 付きで再起動させてログイン流用しようとしない（Chrome 136+ がデフォルト User Data で無効化）
- プロファイルを別パスにコピー／ジャンクションして CDP を通そうとしない（App-Bound Encryption でログインが消える）

## Notes

- プロファイルは `%LOCALAPPDATA%\Google\Chrome\AgentBrowserProfile`（名前は `AGENT_BROWSER_WIN_PROFILE` で変更可。8文字以上・予約名不可）
- 環境変数 `AGENT_BROWSER_WIN_PROFILE` / `AGENT_BROWSER_WIN_CDP_PORT` / `AGENT_BROWSER_WIN_SESSION` はラッパーが Windows PowerShell へ明示転送する（裸の `AGENT_BROWSER_SESSION` はレガシー。Linux 実験の値が残っていると daemon mismatch の原因になる）
- 引数エンコードに WSL 側の `python3` が必要（無いと `open` / `snapshot` 等が失敗する）
- 普段の Chrome と同時起動してよい
- 実装は Windows 側 `agent-browser` + PowerShell ヘルパー。ラッパーが UNC 回避・引数エンコード・PATH 解決を吸収する
- CDP は「listen している」だけでなく **専用プロファイル＋ポートの所有者** かを検証する。他人のポート占有時は明示エラー → `AGENT_BROWSER_WIN_CDP_PORT` を変える
- 同一プロファイル＋ポートの呼び出しは mutex で直列化される（並列エージェントでも daemon reset が衝突しにくい）
- 塞げない制約: 普段の Chrome User Data は CDP 不可 / WSL→Windows localhost 不可 / プロファイルコピーではログイン不可（詳細は `docs/agent-browser-win.md`）
