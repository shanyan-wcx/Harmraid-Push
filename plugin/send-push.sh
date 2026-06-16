#!/bin/bash
# Harmraid Push - 发送通知到 HarmonyOS 设备
# 由 event/notify 钩子调用，无需手动执行

readonly CONFIG_DIR="/boot/config/plugins/harmraid-push"
readonly PUSH_ENABLED_FILE="${CONFIG_DIR}/push_enabled.txt"
readonly TYPES_FILE="${CONFIG_DIR}/types.txt"
readonly TOKEN_FILE="${CONFIG_DIR}/push_token.txt"
readonly APP_ID_FILE="${CONFIG_DIR}/client_id.txt"
readonly APP_SECRET_FILE="${CONFIG_DIR}/client_secret.txt"

TITLE="${1:-Harmraid 通知}"
CONTENT="${2:-}"
SEVERITY="${3:-info}"

# 检查推送是否启用
push_enabled=$(cat "$PUSH_ENABLED_FILE" 2>/dev/null || echo "false")
if [ "$push_enabled" != "true" ]; then
  exit 0
fi

# 检查通知类型是否匹配
allowed_types=$(cat "$TYPES_FILE" 2>/dev/null || echo "alert,warning,info")
if ! echo "$allowed_types" | grep -q "$SEVERITY"; then
  exit 0
fi

# 检查令牌和凭证
if [ ! -f "$TOKEN_FILE" ] || [ ! -f "$APP_ID_FILE" ] || [ ! -f "$APP_SECRET_FILE" ]; then
  logger -t harmraid-push "Push not configured: missing token or credentials"
  exit 1
fi

TOKEN=$(cat "$TOKEN_FILE")
APP_ID=$(cat "$APP_ID_FILE")
APP_SECRET=$(cat "$APP_SECRET_FILE")

# 获取 HMS OAuth 令牌
AUTH_RESPONSE=$(curl -s -X POST \
  "https://oauth-login.cloud.huawei.com/oauth2/v3/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=${APP_ID}&client_secret=${APP_SECRET}")

AUTH_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.access_token' 2>/dev/null)

if [ -z "$AUTH_TOKEN" ] || [ "$AUTH_TOKEN" = "null" ]; then
  logger -t harmraid-push "Failed to get HMS OAuth token"
  exit 1
fi

# 遍历所有 token 逐条发送
while IFS= read -r token_line; do
  [ -z "$token_line" ] && continue
  TOKEN=$(echo "$token_line" | tr -d '[:space:]')
  [ -z "$TOKEN" ] && continue

  curl -s -X POST \
    "https://push-api.cloud.huawei.com/v1/${APP_ID}/messages:send" \
    -H "Authorization: Bearer ${AUTH_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$(cat <<EOF
{
  "message": {
    "token": ["${TOKEN}"],
    "notification": {
      "title": "${TITLE}",
      "body": "${CONTENT}"
    },
    "data": "{\"title\":\"${TITLE}\",\"content\":\"${CONTENT}\",\"severity\":\"${SEVERITY}\"}"
  }
}
EOF
)"
done < "$TOKEN_FILE"
