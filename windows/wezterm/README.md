# WezTerm（Windows）+ WSL + terminal-browser

**WSL2 + Windows 専用。** 純 Ubuntu の TB は herdr 公式ネスト（[docs/herdr.md](../../docs/herdr.md)）。

## 症状

| 症状 | 対処 |
| --- | --- |
| 真っ黒 | nightly WezTerm、このウィンドウの WSL、`enable_kitty_graphics`、herdr `kitty_graphics` |
| スクロール遅い / 検索不安定 | [../wsl/README.md](../wsl/README.md) → `wsl --shutdown` |
| herdr **ネスト**だけ遅い／ツールバー不可 | ネスト禁止。`Ctrl+Alt+I` / `tb-split` / `Ctrl+Shift+B` |
| 日本語 1 文字落ち | `enable_kitty_keyboard = false`（反映済み）。[wezterm#7944](https://github.com/wezterm/wezterm/pull/7944)。副作用: `Ctrl+Alt+Shift+文字` が herdr に正しく届かない → [docs/herdr.md](../../docs/herdr.md) |
| herdr の `Ctrl+Alt` が WezTerm に吸われる | lua でデフォルトの `CTRL\|ALT+"/%` 分割と `CTRL\|SHIFT\|ALT+矢印` を `DisableDefaultAssignment` 済み |

## セットアップ

```bash
./setup.sh                 # または ./windows/setup.sh / --windows-only
./windows/wezterm/setup.sh
./stow.sh restow bin
./windows/wezterm/doctor.sh
```

winget nightly はハッシュずれしやすい → 初回のみ管理者で `winget settings --enable InstallerHashOverride`。

## ファイル

| ファイル | 役割 |
| --- | --- |
| `wezterm.lua` | `%USERPROFILE%\.wezterm.lua`（`Ctrl+Shift+B` split、`Ctrl+Shift+W` ペイン閉じ） |
| `tb-split.sh` / `.ps1` | herdr / CLI からの兄弟 split（生きている gui-sock のみ） |
| `setup.sh` / `.ps1` | lua・フォント・nightly |
| `doctor.sh` | 診断 |

`tb-split` / `wezterm` ラッパーは `stow/bin`。

## 新規タブ cwd

常に WSL `~`（[#5038](https://github.com/wezterm/wezterm/issues/5038)）。
