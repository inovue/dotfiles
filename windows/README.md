# Windows host configs

WSL の Ansible / Stow（`ansible/`, `stow/`）とは別に、**Windows 側に置く設定・セットアップ**をここに置く。

| パス | 役割 |
| --- | --- |
| `wezterm/` | WezTerm（Windows ホスト）の `~/.wezterm.lua` とセットアップ |
| （参考）`../scripts/*agent_browser_win*` | WSL→Windows Chrome ブリッジ（既存。将来ここへ寄せてもよい） |

## なぜ分けるか

- Stow は Linux `$HOME` をミラーする。Windows の `%USERPROFILE%\.wezterm.lua` は対象外
- Ansible は Ubuntu プロビジョニング用。WezTerm の winget / GUI 設定は別ライフサイクル
- WSL から「同期・診断」する入口だけ bash、実体の Windows 操作は `.ps1`

## まずやること（terminal-browser 真っ黒対策）

```bash
./windows/wezterm/setup.sh   # 設定同期 + WezTerm nightly (winget)
./windows/wezterm/doctor.sh
```

その後 **WezTerm を開き直して** WSL に入り、`terminal-browser open https://example.com`。

詳細: [wezterm/README.md](wezterm/README.md)
