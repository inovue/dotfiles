# herdr 使い方（この dotfiles の設定込み）

[herdr](https://herdr.dev) はエージェント／ワークスペース向けターミナルマルチプレクサ。  
このリポジトリでは Ansible で本体＋プラグインを入れ、Stow で設定をリンクする。

## 前提

Kitty graphics 対応の外側ターミナルが必要。この環境では **WezTerm nightly**（セットアップ・IME・真っ黒対策の SSOT: [windows/wezterm/README.md](../windows/wezterm/README.md)）。

## 設定の置き場

| パス | 内容 |
| --- | --- |
| `stow/herdr/.config/herdr/config.toml` | 本体設定・キーバインド（→ `~/.config/herdr/config.toml`） |
| `stow/herdr/.../plugins/config/jhochenbaum.hunkdiff/config.toml` | hunk-diff プラグイン設定 |
| Ansible `tools` ロール | herdr / herdr-hunk-diff / terminal-browser CLI + herdr plugin |

変更後:

```bash
./stow.sh restow herdr
herdr server reload-config
```

## インストールされるもの

| 名前 | 役割 |
| --- | --- |
| `herdr` | マルチプレクサ本体 |
| `jhochenbaum.hunkdiff` | エージェント変更のレビュー → コメントを agent に返す |
| `zenbu-labs.terminal-browser` | 右スプリットで terminal-browser を開く |
| `hunk` / `hunkdiff`（npm） | レビュー UI（プラグインが利用） |
| `terminal-browser` CLI | ブラウザ本体＋ `action`（agent-browser 互換） |

確認:

```bash
herdr --version
herdr plugin list
terminal-browser --version
```

## キーバインド（prefix = `Ctrl+B`）

| キー | 動作 |
| --- | --- |
| `Ctrl+B` `Shift+H` | hunk: 変更をレビュー |
| `Ctrl+B` `Shift+S` | hunk: コメントを agent に送信 |
| `Ctrl+B` `Shift+C` | hunk: 最新コミットをレビュー |
| `Ctrl+B` `Shift+A` | hunk: staged をレビュー |
| `Ctrl+B` `Shift+B` | terminal-browser を右スプリットで開く |
| `Ctrl+B` `Alt+G` | lazygit（popup） |

## 本体設定の要点

`config.toml` で有効にしているもの:

- `mouse_capture = true` — ペイン内クリック（terminal-browser 向け）
- `host_cursor = "native"` — WSL/Windows で日本語 IME の候補位置を確保
- `kitty_graphics = true` — terminal-browser 描画に必須
- `reveal_hidden_cursor_for_cjk_ime` / `cjk_ime_cursor_shape` — カーソル非表示 TUI 向け IME 補助

WezTerm 側の graphics / keyboard: [windows/wezterm/README.md](../windows/wezterm/README.md)。

---

## Plugin: hunk-diff（`jhochenbaum.hunkdiff`）

公式: [herdr-hunk-diff](https://github.com/jhochenbaum/herdr-hunk-diff)

### 何が便利か

素の pane で `hunk` を開くのは「diff 閲覧」。  
プラグインは **インラインコメントを紐づいた agent に返す**（`send-review`）ための往復用。

### 推奨フロー（公式どおり）

1. レビューしたい **agent / worktree のペインにフォーカス**
2. `Ctrl+B` `Shift+H` で review（デフォルト配置は split）
3. hunk でコメント
4. `Ctrl+B` `Shift+S` で agent に送信

この dotfiles のプラグイン設定:

```toml
[review]
auto_open = true   # agent が idle など設定状態になったら自動で開く／更新
watch = true       # ソース変更でレビューを追従
```

（公式デフォルトは `auto_open = false` / `reuse_pane = true` / `placement = "split"`。未指定の `reuse_pane` は true のまま。）

### 複数 agent について

- index は **worktree につき送信先 agent 1つ・review pane 1つ**
- **同じ checkout を共有**しているときは、送りたい agent にフォーカスしてから `review` を開くか、`send-review` をそのペインから実行する
- agent ごとに完全分離したいなら **別 git worktree** が設計と一番合う
- 既に review が別タブにあると、再利用時は新規を開かず既存を reload する（タブ自動フォーカスはしない）

CLI 例:

```bash
herdr plugin action invoke review --plugin jhochenbaum.hunkdiff
herdr plugin action invoke send-review --plugin jhochenbaum.hunkdiff
herdr plugin log list --plugin jhochenbaum.hunkdiff
```

---

## Plugin: terminal-browser（`zenbu-labs.terminal-browser`）

公式: [zenbu-labs/terminal-browser](https://github.com/zenbu-labs/terminal-browser)  
herdr plugin: [herdr-plugin](https://github.com/zenbu-labs/terminal-browser/tree/main/herdr-plugin)

### herdr での開き方

- キー: `Ctrl+B` `Shift+B` → フォーカスペインの右に split
- または agent／シェルから:

```bash
terminal-browser open https://example.com --split right
terminal-browser open ./plan.html --split right
terminal-browser open --ssh user@host localhost:3000
```

公式ユースケースは **同じ herdr タブで agent とサイトを並べる**こと。

### agent-browser「統合」とは

別プロセスの `agent-browser` を繋ぐ話ではない。  
**いま開いている terminal-browser** を、agent-browser 互換 CLI で操作する:

```bash
terminal-browser ls
terminal-browser action -- snapshot
terminal-browser action -- click @e14
terminal-browser action -- fill @e3 "hello"
terminal-browser action done    # 操作インジケータをすぐ消す（推奨）
```

Cursor 向け skill `terminal-browser` も install 済み（agent にこの CLI を使わせる）。

### 混同しやすいツール

| ツール | 用途 |
| --- | --- |
| `terminal-browser` + `action` | ターミナル内ブラウザを視覚的に並べて操作 |
| `agent-browser`（Linux） | Chrome for Testing 等の自動化 |
| `agent-browser-win` | ログイン済み Windows Chrome（[docs/agent-browser-win.md](agent-browser-win.md)） |

プラグイン設定ディレクトリにユーザー設定ファイルは不要（キーは `config.toml` 側）。

---

## lazygit

`Ctrl+B` `Alt+G` で popup（90%）。プラグインではない。

---

## よくあるトラブル

| 症状 | 確認 |
| --- | --- |
| TB 真っ黒 / JP IME 1文字落ち | [windows/wezterm/README.md](../windows/wezterm/README.md)（SSOT）+ herdr `kitty_graphics = true` |
| hunk が「開かない」ように見える | 同じ worktree の review が別タブに既にあると reuse／reload のみ |
| `send-review` が届かない | 対象 agent ペインにフォーカスしてから review／send |
| 設定が効かない | `./stow.sh restow herdr` → `herdr server reload-config` |
| herdr を上げたのに古い | `herdr status` → 必要なら `herdr server stop` して再起動 |

---

## 更新・再インストール

ピンは `ansible/group_vars/all.yml`（`herdr_pin` / `herdr_hunkdiff_pin` / `terminal_browser_pin` など）。

```bash
./setup.sh --tags herdr
# または
./setup.sh --tags terminal-browser
```
