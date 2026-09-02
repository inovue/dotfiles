#!/usr/bin/env zsh

# 1. Bitwarden Send の URL を確認
if [ -z "$1" ]; then
  echo "エラー: Bitwarden Send の URL を指定してください。"
  echo "使用例: ./scripts/setup_bws.sh \"https://send.bitwarden.com/#...\""
  exit 1
fi

SEND_URL="$1"

# 2. URL から ID と 暗号化キーを抽出
# 形式: https://send.bitwarden.com/#<send_id>/<key>
FRAGMENT=$(echo "$SEND_URL" | sed -n 's#.*\#\([^/]*\)/\([^/]*\)#\1 \2#p')
SEND_ID=$(echo "$FRAGMENT" | awk '{print $1}')
B64_KEY=$(echo "$FRAGMENT" | awk '{print $2}')

if [ -z "$SEND_ID" ] || [ -z "$B64_KEY" ]; then
  echo "エラー: URL のフォーマットが無効です。"
  exit 1
fi

echo "Bitwarden Send からデータを取得中..."

# 3. Bitwarden API から暗号化ペロードを取得
RESPONSE=$(curl -s "https://vault.bitwarden.com/api/sends/$SEND_ID")

# レスポンスから暗号化されたテキスト ( cipherText ) を抽出
ENCRYPTED_TEXT=$(echo "$RESPONSE" | grep -o '"text":{"text":"[^"]*' | sed 's/"text":{"text":"//')

if [ -z "$ENCRYPTED_TEXT" ]; then
  echo "エラー: データの取得に失敗したか、Send が無効・期限切れです。"
  exit 1
fi

# 4. 暗号化データを復号 (AES-256-CBC)
# Bitwarden Send の暗号化形式: 2.<iv>|<cipherText>
IV_B64=$(echo "$ENCRYPTED_TEXT" | cut -d'|' -f1 | sed 's/2\.//')
CIPHER_B64=$(echo "$ENCRYPTED_TEXT" | cut -d'|' -f2)

# OpenSSL で復号できるようにキーとIVを Hex 変換
KEY_HEX=$(echo "$B64_KEY" | base64 --decode 2>/dev/null | xxd -p | tr -d '\n')
IV_HEX=$(echo "$IV_B64" | base64 --decode 2>/dev/null | xxd -p | tr -d '\n')

TOKEN=$(echo "$CIPHER_B64" | base64 --decode 2>/dev/null | openssl enc -d -aes-256-cbc -K "$KEY_HEX" -iv "$IV_HEX" 2>/dev/null)

if [ -z "$TOKEN" ]; then
  echo "エラー: トークンの復号に失敗しました。"
  exit 1
fi

# 5. ~/.config/inovue/bws.env への書き込み
BWS_ENV="$HOME/.config/inovue/bws.env"
mkdir -p "$(dirname "$BWS_ENV")"

printf 'export BWS_ACCESS_TOKEN="%s"\n' "$TOKEN" > "$BWS_ENV"
chmod 600 "$BWS_ENV"

echo "成功: $BWS_ENV に BWS_ACCESS_TOKEN を書き込みました。"
echo "設定を即時反映するには 'exec zsh' を実行してください。"
