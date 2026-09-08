# WezTerm（Windows）+ WSL + terminal-browser

## 症状: 何も表示されない / 真っ黒

1. **WezTerm が古すぎる** — stable `20240203` では不可。**nightly**（`wez.wezterm.nightly`）が必要
2. **Windows Terminal / Cursor 内蔵端末** — WezTerm ウィンドウ内の WSL で起動すること
3. **設定未反映** — `enable_kitty_graphics = true`（`wezterm.lua`）
4. **herdr 内** — `[experimental] kitty_graphics = true`（Stow 管理済み）

## 症状: herdr 内で日本語が 1 文字だけ確定できない／消える

WezTerm の既知バグ: Kitty keyboard 有効時、IME 確定の **1 コードポイント** `Composed` が `encode_kitty` で空文字になり落とされる（[wezterm#7944](https://github.com/wezterm/wezterm/pull/7944)、未マージ）。

**現状の回避:** `enable_kitty_keyboard = false`（dotfiles 反映済み）。graphics は維持。#7944 入り nightly 後に true へ戻せる。

| 関連 | 内容 |
| --- | --- |
| herdr | `host_cursor = "native"` + `reveal_hidden_cursor_for_cjk_ime = true`（候補位置／不可視向け） |
| 確認 | `debug_key_events = true` で `Composed("…")` → `kitty: Encoded input as ""` |

## セットアップ

```bash
./windows/wezterm/setup.sh    # lua 同期 + UDEV Gothic 35NFLG + winget nightly
./windows/wezterm/doctor.sh
```

Windows から:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\windows\wezterm\setup.ps1
```

`winget` がハッシュで落ちるとき（nightly でありがち）は、管理者 PowerShell で一度だけ:

```powershell
winget settings --enable InstallerHashOverride
```

その後 `setup.sh` を再実行。

## ファイル

| ファイル | 役割 |
| --- | --- |
| `wezterm.lua` | → `%USERPROFILE%\.wezterm.lua`（フォント: UDEV Gothic 35NFLG / 8pt） |
| `setup.sh` / `setup.ps1` | 同期 + UDEV Gothic 35NFLG インストール + `winget install wez.wezterm.nightly` |
| `doctor.sh` | 診断 |

WSL の `wezterm` ラッパーは `stow/bin`（`wezterm.exe` へ）。

## 新規タブの cwd

常に WSL ホーム（`~`）。公式に「新規タブは常に default_cwd」オプションは無いため、
`SpawnCommandInNewTab` / `+` ボタン / 新ウィンドウで `cwd = '~'` を明示している（[#5038](https://github.com/wezterm/wezterm/issues/5038)）。
