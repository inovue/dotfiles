#!/usr/bin/env zsh

# 1. Bitwarden Send の URL を確認
if [ -z "$1" ]; then
  echo "エラー: Bitwarden Send の URL を指定してください。"
  echo "使用例: ./scripts/setup_bws.sh \"https://send.bitwarden.com/#...\""
  exit 1
fi

SEND_URL="$1"

# 2. URL から ID とキーを抽出（形式チェック用）
# 形式: https://send.bitwarden.com/#<send_id>/<key>
FRAGMENT=$(echo "$SEND_URL" | sed -n 's#.*\#\([^/]*\)/\([^/]*\)#\1 \2#p')
SEND_ID=$(echo "$FRAGMENT" | awk '{print $1}')
B64_KEY=$(echo "$FRAGMENT" | awk '{print $2}')

if [ -z "$SEND_ID" ] || [ -z "$B64_KEY" ]; then
  echo "エラー: URL のフォーマットが無効です。"
  exit 1
fi

receive_send_token() {
  local url="$1"

  if command -v bw >/dev/null 2>&1; then
    BW_NOINTERACTION=true bw send receive "$url" 2>/dev/null
    return $?
  fi

  if command -v npx >/dev/null 2>&1; then
    BW_NOINTERACTION=true npx --yes @bitwarden/cli send receive "$url" 2>/dev/null
    return $?
  fi

  echo "エラー: Bitwarden CLI (bw) が見つかりません。" >&2
  echo "  npm install -g @bitwarden/cli" >&2
  echo "  または Node.js + npx をインストールしてください。" >&2
  return 127
}

echo "Bitwarden Send からデータを取得中..."

TOKEN=$(receive_send_token "$SEND_URL")
RC=$?
TOKEN=$(echo "$TOKEN" | tr -d '\r\n')

if [ "$RC" -ne 0 ] || [ -z "$TOKEN" ]; then
  echo "エラー: データの取得に失敗したか、Send が無効・期限切れです。"
  exit 1
fi

# 3. ~/.config/inovue/bws.env への書き込み
BWS_ENV="$HOME/.config/inovue/bws.env"
mkdir -p "$(dirname "$BWS_ENV")"

printf 'export BWS_ACCESS_TOKEN="%s"\n' "$TOKEN" > "$BWS_ENV"
chmod 600 "$BWS_ENV"

echo "成功: $BWS_ENV に BWS_ACCESS_TOKEN を書き込みました。"
echo "設定を即時反映するには 'exec zsh' を実行してください。"
