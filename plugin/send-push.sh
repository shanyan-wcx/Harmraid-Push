#!/bin/bash
# Harmraid Push - 发送通知到 HarmonyOS 设备 (V3 JWT API)
# 由 event/notify 钩子调用

readonly CONFIG_DIR="/boot/config/plugins/harmraid-push"
readonly PUSH_ENABLED_FILE="${CONFIG_DIR}/push_enabled.txt"
readonly TYPES_FILE="${CONFIG_DIR}/types.txt"
readonly TOKEN_FILE="${CONFIG_DIR}/push_token.txt"
readonly SA_FILE="${CONFIG_DIR}/service-account.json"
readonly TMPKEY="/tmp/harmraid-push-key.pem"

TITLE="${1:-Harmraid 通知}"
CONTENT="${2:-}"
SEVERITY="${3:-info}"

# 检查推送是否启用
push_enabled=$(cat "$PUSH_ENABLED_FILE" 2>/dev/null || echo "false")
[ "$push_enabled" != "true" ] && exit 0

# 检查通知类型
allowed_types=$(cat "$TYPES_FILE" 2>/dev/null || echo "alert,warning,info")
echo "$allowed_types" | grep -q "$SEVERITY" || exit 0

# 检查服务账号密钥
[ ! -f "$SA_FILE" ] && logger -t harmraid-push "service-account.json not found" && exit 1
[ ! -f "$TOKEN_FILE" ] && exit 0

# 解析服务账号密钥
SA_JSON=$(cat "$SA_FILE")
PROJECT_ID=$(echo "$SA_JSON" | jq -r '.project_id')
KEY_ID=$(echo "$SA_JSON" | jq -r '.key_id')
PRIVATE_KEY=$(echo "$SA_JSON" | jq -r '.private_key')
SUB_ACCOUNT=$(echo "$SA_JSON" | jq -r '.sub_account')
TOKEN_URI=$(echo "$SA_JSON" | jq -r '.token_uri')

[ -z "$PROJECT_ID" ] && logger -t harmraid-push "Invalid service-account.json" && exit 1

# 生成 JWT
NOW=$(date +%s)
EXP=$((NOW + 3600))

HEADER="{\"alg\":\"RS256\",\"typ\":\"JWT\",\"kid\":\"${KEY_ID}\"}"
PAYLOAD="{\"iss\":\"${SUB_ACCOUNT}\",\"aud\":\"https://oauth-login.cloud.huawei.com/oauth2/v3/token\",\"exp\":${EXP},\"iat\":${NOW}}"

B64_H=$(echo -n "$HEADER" | openssl base64 -e | tr -d '\n=' | tr '+/' '-_')
B64_P=$(echo -n "$PAYLOAD" | openssl base64 -e | tr -d '\n=' | tr '+/' '-_')

echo "$PRIVATE_KEY" > "$TMPKEY"
SIGN=$(echo -n "${B64_H}.${B64_P}" | openssl dgst -sha256 -sign "$TMPKEY" | openssl base64 -e | tr -d '\n=' | tr '+/' '-_')
rm -f "$TMPKEY"

JWT="${B64_H}.${B64_P}.${SIGN}"

# 换取 access token
TOKEN_RESP=$(curl -s -X POST "$TOKEN_URI" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${JWT}")

ACCESS_TOKEN=$(echo "$TOKEN_RESP" | jq -r '.access_token')

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
  logger -t harmraid-push "Failed to get access token: $(echo $TOKEN_RESP | jq -r '.error_description')"
  exit 1
fi

# 读取所有推送 token（去空行、去重）
TOKENS=$(jq -R -s '[split("\n")[] | select(length > 0)] | unique' "$TOKEN_FILE" 2>/dev/null)
[ -z "$TOKENS" ] || [ "$TOKENS" = "[]" ] && exit 0

# V3 批量发送推送
RESP=$(curl -s -X POST \
  "https://push-api.cloud.huawei.com/v3/${PROJECT_ID}/messages:send" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "push-type: 0" \
  -d "$(cat <<EOF
{
  "payload": {
    "notification": {
      "category": "DEVICE_REMINDER",
      "title": "${TITLE}",
      "body": "${CONTENT}",
      "clickAction": {
        "actionType": 0
      },
      "foregroundShow": true
    },
    "data": "{\"title\":\"${TITLE}\",\"content\":\"${CONTENT}\",\"severity\":\"${SEVERITY}\"}"
  },
  "target": {
    "token": ${TOKENS}
  },
  "pushOptions": {
    "testMessage": true,
    "ttl": 86400
  }
}
EOF
)"

logger -t harmraid-push "Push sent: ${TITLE} (${SEVERITY}) - $(echo $RESP | jq -c '.msg // .code')"
