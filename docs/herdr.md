# herdr

[herdr](https://herdr.dev) ターミナルマルチプレクサ。Ansible で本体＋プラグイン、Stow で設定。

## 設定

| パス | 内容 |
| --- | --- |
| `stow/herdr/.config/herdr/config.toml` | キー・プラグイン |
| Ansible `tools` | herdr / hunk-diff / file-viewer |

```bash
./stow.sh restow herdr
herdr server reload-config
```

## キー設計

主軸は **`Ctrl+Alt`**（prefix-free）。直感は VS Code の文字ニュアンス:

| VS Code | → `Ctrl+Alt` |
| --- | --- |
| Sidebar `Ctrl+B` | `B` |
| Settings `Ctrl+,` | `,` |
| Quick Open `Ctrl+P` | `P` |
| SCM `Ctrl+Shift+G` | `G`（lazygit） |
| Split `Ctrl+\` | `\` |
| Close `Ctrl+W` | `W` |
| New `Ctrl+N` | `N` |
| Keybindings | `S`（help） |
| Explorer | `F`（file-viewer） |
| Problems | `M`（hunk review） |

ペイン移動: **`H J K L`**. ヘルプ: **`Ctrl+Alt+S`** または `Ctrl+B` `?`

### Direct（`Ctrl+Alt`）

| キー | 動作 |
| --- | --- |
| `H` `J` `K` `L` | ペイン focus |
| `N` | 新タブ |
| `\` / `-` | 縦 / 横分割 |
| `W` / `X` | ペイン / タブ閉じ |
| `Z` | zoom |
| `B` / `A` / `P` | サイドバー / WS picker / goto |
| `M` / `U` | hunk review / send |
| `F` / `G` | file viewer / lazygit |

### Prefix（`Ctrl+B` のあと）

| キー | 動作 |
| --- | --- |
| `Shift+H/J/K/L` | ペイン swap |
| `Shift+C/A` · `Alt+B/U/Y/X` | hunk commit/staged/branch/stash/reload/close |
| `Alt+N/P` | hunk 次 / 前コメント |
| `Shift+F` | file viewer（tab） |
| `Shift+R` | reload config |

## Plugins

- **hunk:** `Ctrl+Alt+M` review、`Ctrl+Alt+U` send
- **file-viewer:** `Ctrl+Alt+F`（tab は `Ctrl+B` `Shift+F`）— markdown に `glow` を使用
- **lazygit:** `Ctrl+Alt+G`

## トラブル

| 症状 | 確認 |
| --- | --- |
| 設定反映 | `./stow.sh restow herdr` → `herdr server reload-config` |
| バイナリ更新後おかしい | `herdr server stop` のあと再 attach |
