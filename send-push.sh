#!/bin/bash
# Harmraid Push - Send notification to HarmonyOS device via HMS Push Kit
# Usage: send-push.sh <title> <content> [severity]
#   severity: info (default), warning, error, alert

readonly CONFIG_DIR="/boot/config/plugins/harmraid-push"
readonly TOKEN_FILE="${CONFIG_DIR}/push_token.txt"
readonly APP_ID_FILE="${CONFIG_DIR}/app_id.txt"
readonly APP_SECRET_FILE="${CONFIG_DIR}/app_secret.txt"

TITLE="${1:-Harmraid 通知}"
CONTENT="${2:-}"
SEVERITY="${3:-info}"

if [ ! -f "$TOKEN_FILE" ]; then
  logger -t harmraid-push "No push token found. Device not registered."
  exit 1
fi

if [ ! -f "$APP_ID_FILE" ] || [ ! -f "$APP_SECRET_FILE" ]; then
  logger -t harmraid-push "HMS credentials not configured."
  exit 1
fi

TOKEN=$(cat "$TOKEN_FILE")
APP_ID=$(cat "$APP_ID_FILE")
APP_SECRET=$(cat "$APP_SECRET_FILE")

# Get HMS OAuth Token
AUTH_RESPONSE=$(curl -s -X POST \
  "https://oauth-login.cloud.huawei.com/oauth2/v3/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=${APP_ID}&client_secret=${APP_SECRET}")

AUTH_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.access_token' 2>/dev/null)

if [ -z "$AUTH_TOKEN" ] || [ "$AUTH_TOKEN" = "null" ]; then
  logger -t harmraid-push "Failed to get HMS OAuth token."
  exit 1
fi

# Send push notification
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

logger -t harmraid-push "Push sent: ${TITLE}"
