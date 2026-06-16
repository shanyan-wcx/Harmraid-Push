#!/bin/bash
# Harmraid Push - 发送通知到 HarmonyOS 设备 (V3 JWT API)
# 由 event/notify 钩子调用

readonly CONFIG_DIR="/boot/config/plugins/harmraid-push"
readonly SA_FILE="${CONFIG_DIR}/service-account.json"
readonly SA_ENC_FILE="${CONFIG_DIR}/service-account.json.enc"
readonly TMPKEY="/tmp/harmraid-push-key.pem"
readonly SA_TMP="/dev/shm/service-account.json"

TITLE="${1:-Harmraid 通知}"
CONTENT="${2:-}"
SEVERITY="${3:-INFO}"

# 解密服务账号密钥（优先 .enc，降级 .json）
if [ -f "$SA_ENC_FILE" ]; then
  openssl enc -d -aes-256-cbc -salt -md md5 -in "$SA_ENC_FILE" -out "$SA_TMP" -pass pass:"HARMRAID_PUSH_SECRET_2024" 2>/dev/null
  if [ $? -eq 0 ] && [ -s "$SA_TMP" ]; then
    SA_JSON=$(cat "$SA_TMP")
    rm -f "$SA_TMP"
  else
    logger -t harmraid-push "Failed to decrypt service-account.json.enc"
    exit 1
  fi
elif [ -f "$SA_FILE" ]; then
  SA_JSON=$(cat "$SA_FILE")
else
  logger -t harmraid-push "No service account key"
  exit 1
fi
[ ! -f "$CONFIG_DIR/devices.json" ] && exit 0

# 解析服务账号密钥
PROJECT_ID=$(echo "$SA_JSON" | jq -r '.project_id')
KEY_ID=$(echo "$SA_JSON" | jq -r '.key_id')
PRIVATE_KEY=$(echo "$SA_JSON" | jq -r '.private_key')
SUB_ACCOUNT=$(echo "$SA_JSON" | jq -r '.sub_account')

[ -z "$PROJECT_ID" ] && logger -t harmraid-push "Invalid service-account.json" && exit 1

# 从 devices.json 读取所有推送 token
TOKENS=$(jq '[.[].token]' "$CONFIG_DIR/devices.json" 2>/dev/null)
[ -z "$TOKENS" ] || [ "$TOKENS" = "[]" ] && exit 0

# 生成 JWT
NOW=$(date +%s)
EXP=$((NOW + 3600))

HEADER="{\"alg\":\"RS256\",\"typ\":\"JWT\",\"kid\":\"${KEY_ID}\"}"
PAYLOAD="{\"iss\":\"${SUB_ACCOUNT}\",\"aud\":\"https://push-api.cloud.huawei.com\",\"exp\":${EXP},\"iat\":${NOW}}"

B64_H=$(echo -n "$HEADER" | openssl base64 -e | tr -d '\n=' | tr '+/' '-_')
B64_P=$(echo -n "$PAYLOAD" | openssl base64 -e | tr -d '\n=' | tr '+/' '-_')

echo "$PRIVATE_KEY" > "$TMPKEY"
SIGN=$(echo -n "${B64_H}.${B64_P}" | openssl dgst -sha256 -sign "$TMPKEY" | openssl base64 -e | tr -d '\n=' | tr '+/' '-_')
rm -f "$TMPKEY"

JWT="${B64_H}.${B64_P}.${SIGN}"

# V3 批量发送推送
PAYLOAD_FILE="/tmp/harmraid-push-payload.json"
cat > "$PAYLOAD_FILE" << EOFJSON
{
  "payload": {
    "notification": {
      "category": "DEVICE_REMINDER",
      "title": "${TITLE}",
      "body": "${CONTENT}",
      "clickAction": { "actionType": 0 },
      "foregroundShow": true
    },
    "data": "{\"title\":\"${TITLE}\",\"content\":\"${CONTENT}\",\"severity\":\"${SEVERITY}\"}"
  },
  "target": {
    "token": ${TOKENS}
  },
  "pushOptions": {
    "ttl": 86400
  }
}
EOFJSON

RESP=$(curl -s -X POST \
  "https://push-api.cloud.huawei.com/v3/${PROJECT_ID}/messages:send" \
  -H "Authorization: Bearer ${JWT}" \
  -H "Content-Type: application/json" \
  -H "push-type: 0" \
  -d @"$PAYLOAD_FILE")

rm -f "$PAYLOAD_FILE"

echo "HMS response: $(echo $RESP | jq -c '.code // .msg // "unknown"')"
logger -t harmraid-push "Push sent: ${TITLE} (${SEVERITY}) - $(echo $RESP | jq -c '.msg // .code')"
