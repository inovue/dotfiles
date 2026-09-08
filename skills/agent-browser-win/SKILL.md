---
name: agent-browser-win
description: >-
  Drive a logged-in Windows Chrome from WSL/Cursor via a dedicated CDP profile
  (agent-browser-win). Use when automating browsers that need real login state
  on WSL2+Windows11, or when Linux agent-browser profile reuse fails.
---

# agent-browser-win

WSL2 + Windows 11 + Cursor。ログイン済み Windows Chrome は **このラッパーのみ**（Linux `agent-browser` 直起動や普段の Chrome User Data は使わない）。

## When to use

- Gmail / SSO など **実ログイン状態** が必要
- Windows の普段プロファイルを `--profile` しようとしている（それは失敗する）

## Do this

```bash
agent-browser-win start
agent-browser-win open <url>
agent-browser-win snapshot -i
agent-browser-win stop          # optional
agent-browser-win status|doctor
```

Broken / missing install (from this repo):

```bash
./scripts/setup_agent_browser_win.sh
```

Deep docs / env / troubleshooting: `docs/agent-browser-win.md`.

## Do not

- WSL → Windows `connect 9222` / `--cdp` 直叩き（NAT で届かない）
- Linux Chrome に Windows `%LOCALAPPDATA%\Google\Chrome\User Data` を渡す
- 普段 Chrome を `--remote-debugging-port` でログイン流用（Chrome 136+ 無効）
- プロファイルコピー／ジャンクションで CDP（App-Bound Encryption でログイン消失）
