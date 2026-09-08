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
| `stow/bin/.../terminal-browser-open` | `Ctrl+B` `Shift+B` ルーター |
| `stow/bin/.../tb-split` | WSL → `windows/wezterm/tb-split.sh` |
| Ansible `tools` | herdr / hunk-diff / terminal-browser CLI + plugins |

```bash
./stow.sh restow herdr bin
herdr server reload-config
```

## キー（prefix = `Ctrl+B`）

| キー | 動作 |
| --- | --- |
| `Shift+H` / `S` / `C` / `A` | hunk review / send / commit / staged |
| `Shift+B` | terminal-browser（下表） |
| `Alt+G` | lazygit |
| WezTerm `Ctrl+Shift+B` | WSL: 兄弟ペイン（herdr 外） |

### `Shift+B`（`terminal-browser-open`）

| 環境 | 実体 | send-to-agent (`Ctrl+G`) |
| --- | --- | --- |
| Native | herdr `open-split` | 同タブの agent ペインへ届く |
| WSL | `tb-split` | 届かない（兄弟ペインのため） |

WSL でネストしない理由: PTY セル画素 0 → no `direct-kitty`。[windows/wsl/README.md](../windows/wsl/README.md)

## 本体設定の要点

- `mouse_capture = true`
- `host_cursor = "native"`（IME）
- `terminal.kitty_graphics = true`
- `reveal_hidden_cursor_for_cjk_ime` / `cjk_ime_cursor_shape`

---

## Plugin: hunk-diff

公式: [herdr-hunk-diff](https://github.com/jhochenbaum/herdr-hunk-diff)

1. agent / worktree ペインにフォーカス  
2. `Ctrl+B` `Shift+H` → コメント  
3. `Ctrl+B` `Shift+S` → agent に送信  

```toml
[review]
auto_open = true
watch = true
```

worktree 共有時は送りたい agent にフォーカスしてから review／send。完全分離は別 worktree。

---

## Plugin: terminal-browser

公式: [zenbu-labs/terminal-browser](https://github.com/zenbu-labs/terminal-browser)

**Native:** `Ctrl+B` `Shift+B` または `terminal-browser open URL --split right`  
**WSL:** `Ctrl+B` `Shift+B` / `tb-split` / WezTerm `Ctrl+Shift+B`（ネスト禁止）

agent 操作:

```bash
terminal-browser ls
terminal-browser action -- snapshot
terminal-browser action done
```

| ツール | 用途 |
| --- | --- |
| `terminal-browser` + `action` | ターミナル内ブラウザ |
| `agent-browser` | Linux 自動化 |
| `agent-browser-win` | ログイン済み Win Chrome |

---

## トラブル

| 症状 | 確認 |
| --- | --- |
| TB 真っ黒 / JP IME | [windows/wezterm/README.md](../windows/wezterm/README.md) |
| WSL で遅い・検索不安定 | [windows/wsl/README.md](../windows/wsl/README.md) → `wsl --shutdown` |
| WSL ネスト TB が遅い | 想定どおり → 兄弟ペインを使う |
| `Shift+B` 無反応（WSL） | `./stow.sh restow bin`、`tb-split` on PATH |
| Native で plugin 失敗 | `./setup.sh --tags terminal-browser` |
| 設定が効かない | `./stow.sh restow herdr` → `herdr server reload-config` |

```bash
./setup.sh --tags herdr
./setup.sh --tags terminal-browser
```
