# herdr 使い方（この dotfiles の設定込み）

[herdr](https://herdr.dev) はエージェント／ワークスペース向けターミナルマルチプレクサ。  
Ansible で本体＋プラグイン、Stow で設定をリンクする。

## 前提

| 環境 | 外側ターミナル | TB |
| --- | --- | --- |
| **Native Ubuntu** | Kitty / Linux WezTerm 等 | herdr **ネスト**（公式プラグイン） |
| **WSL2 + Windows** | **WezTerm nightly** | WezTerm **兄弟ペイン**のみ |

WezTerm（WSL）: [windows/wezterm/README.md](../windows/wezterm/README.md)

## 設定

| パス | 内容 |
| --- | --- |
| `stow/herdr/.config/herdr/config.toml` | 本体・キー |
| `windows/wezterm/wezterm.lua` | 外側（`CTRL\|ALT` を herdr へ通す） |
| `stow/bin/.../terminal-browser-open` | `Ctrl+Alt+I` ルーター |
| Ansible `tools` | herdr / plugins |

```bash
./stow.sh restow herdr bin
herdr server reload-config
```

## キー設計

軸は **`Ctrl+Alt`**（公式の prefix-free 推奨）。この WezTerm では **素の文字だけ**が確実（`Shift+文字` / 数字 / `?` は欠落）。

直感性は **VS Code の文字ニュアンス**を `Ctrl+Alt` に載せ替え:

| VS Code | → ここ (`Ctrl+Alt`) |
| --- | --- |
| `Ctrl+B` Sidebar | `B` |
| `Ctrl+,` Settings | `,` |
| `Ctrl+P` Quick Open | `P`（goto） |
| `Ctrl+Shift+G` SCM | `G`（lazygit） |
| `Ctrl+\` Split | `\` |
| `Ctrl+W` Close editor | `W`（close pane） |
| `Ctrl+N` New | `N`（new tab） |
| `Ctrl+K Ctrl+S` Keybindings | `S`（help） |
| Zen / focus | `Z`（zoom） |
| Explorer / files | `F` |
| Problems `Ctrl+Shift+M` | `M`（hunk review） |

ペイン移動は端末向けに **`H J K L`**（VS Code に良い文字コードが無い）。

ヘルプ: **`Ctrl+Alt+S`** または `Ctrl+B` `?`

### Direct（`Ctrl+Alt`）

| キー | 動作 |
| --- | --- |
| `H` `J` `K` `L` | ペイン focus |
| `N` | 新タブ |
| `\` / `-` | 縦分割 / 横分割 |
| `W` / `X` | ペイン閉じる / タブ閉じる |
| `Z` | zoom |
| `[` / `]` | 前 / 次タブ |
| `/` / `.` | ペイン cycle |
| `` ` `` | last pane |
| `B` / `A` / `P` | サイドバー / WS picker / goto |
| `R` / `C` / `E` | resize / copy mode / scrollback 編集 |
| `S` / `,` / `O` / `Q` | help / settings / 通知 / detach |
| `;` / `'` | 前 / 次エージェント |
| `M` / `U` | hunk review / send |
| `F` / `I` / `G` | file viewer / TB / lazygit |
| `Shift+←↓↑→` | 直接リサイズ |

### Prefix（`Ctrl+B` のあと）

| キー | 動作 |
| --- | --- |
| `Shift+H/J/K/L` | ペイン swap |
| `Shift+N/W/D` | WS 新規 / 改名 / 閉じる |
| `Shift+G` · `Alt+O` · `Alt+Backspace` | worktree |
| `1`–`9` · `Shift+T/P` | タブジャンプ / 改名 / ペイン改名 |
| `Shift+R` | reload config |
| `Shift+C/A` · `Alt+B/U/Y/X` | hunk commit/staged/branch/stash/reload/close |
| `Alt+N/P` | hunk 次 / 前コメント |
| `Shift+F` | file viewer（tab） |
| WezTerm `Ctrl+Shift+B` | WSL 兄弟 TB |

### 衝突メモ

| コード | 扱い |
| --- | --- |
| `Ctrl+Alt+Shift+文字` | 使わない（Shift 欠落） |
| `Ctrl+Alt+数字` / `?` | 使わない |
| `Ctrl+Alt+Tab` | Win タスク切替 → 不使用 |
| WezTerm `Ctrl+Alt+Shift+W` | タブごと閉じ（ホスト）。素の `Ctrl+Alt+W` は herdr のペイン閉じ |
| `Ctrl+Alt+A` | KDE では注意。この Win+WezTerm では WS picker |

---

## Plugin 要点

**hunk:** `Ctrl+Alt+M` → review、`Ctrl+Alt+U` → send  
**file-viewer:** `Ctrl+Alt+F`（tab は `Ctrl+B` `Shift+F`）  
**TB:** `Ctrl+Alt+I`（WSL は兄弟ペイン）  
**lazygit:** `Ctrl+Alt+G`

```toml
# hunk plugin
[review]
auto_open = true
watch = true
```

---

## トラブル

| 症状 | 確認 |
| --- | --- |
| TB / IME | [windows/wezterm/README.md](../windows/wezterm/README.md) |
| `Ctrl+Alt` が変 | Shift+文字を使っていないか。WezTerm lua 最新か |
| 設定反映 | `./stow.sh restow herdr` → `herdr server reload-config` |
