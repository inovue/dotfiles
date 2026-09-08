# WSL2 `.wslconfig`（Windows）

**WSL では herdr ネスト TB は使わない**（兄弟ペインのみ — [docs/herdr.md](../../docs/herdr.md)）。  
それでも terminal-browser + Cursor agents は WSL 内 Electron / Node を複数常駐させる。  
ホスト RAM が十分でも **`.wslconfig` の `memory=` が低いと** スクロール遅延・入力不安定・OOM っぽい挙動になる。

## 症状

- terminal-browser のスクロールが極端に遅い / 固まる
- ページ検索・URL 欄の入力が効かないように見える
- `MemAvailable` が数百 MiB 台、`Committed_AS` が MemTotal を超える

設定・Kitty graphics は問題なくても、**WSL に渡している RAM が足りない**ことがある。

## セットアップ

`./setup.sh`（WSL 検出時）または `./windows/setup.sh` が自動で適用する。単体:

```bash
./windows/wsl/setup.sh
./windows/wsl/doctor.sh
```

適用後（**必須**）— Windows PowerShell:

```powershell
wsl --shutdown
```

その後 WezTerm を開き直す。

## 配布内容

| ファイル | 役割 |
| --- | --- |
| `.wslconfig` | フロア値（`memory=8GB` / `processors=8`）のテンプレ |
| `setup.ps1` | ホスト RAM/CPU から実値を計算して `%USERPROFILE%\.wslconfig` に書く |
| `doctor.sh` | WSL から見える MemTotal / CPU / ファイル有無を確認 |

目安（setup.ps1）:

| ホスト RAM | WSL `memory` |
| --- | --- |
| ≥16GB | 8–12GB（だいたい半分、上限 12） |
| ≥12GB | 8GB |
| ≥8GB | 6GB |
| それ以下 | host−2（下限 3） |

`processors` は論理 CPU の半分を 4–8 にクランプ。

## 注意

- このセットアップは **`.wslconfig` を上書き**する（手書きの他キーは消える）
- `/etc/wsl.conf`（systemd 等）は別ファイル。触らない
- Linux 版 TB のトラックパッドは macOS ほど滑らかではない（公式制限）。メモリ不足とは別軸
