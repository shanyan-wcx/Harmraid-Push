#!/bin/bash
# Harmraid Push - Device registration background poll
# Called by nohup after plugin install
LOG="/var/log/harmraid-push.log"

echo "[$(date)] [poll] Background poll started" >> "$LOG"
for i in $(seq 1 60); do
  sleep 1
  RESULT=$(curl -s http://localhost/graphql \
    -H "Content-Type: application/json" \
    -d '{"query":"{ notifications { list(filter: { type: UNREAD, offset: 0, limit: 50 }) { id subject description importance } } }"}')
  echo "[$(date)] [poll] attempt $i: $(echo "$RESULT" | head -c 200)" >> "$LOG"
  ERR=$(echo "$RESULT" | jq -r '.errors // ""' 2>/dev/null)
  [ -n "$ERR" ] && echo "[$(date)] [poll] GraphQL errors: $ERR" >> "$LOG"
  COUNT=$(echo "$RESULT" | jq '.data.notifications.list | length // 0' 2>/dev/null)
  echo "[$(date)] [poll] notifications count: $COUNT" >> "$LOG"
  REG_ID=$(echo "$RESULT" | jq -r '.data.notifications.list[] | select(.subject == "HARMRAID_PUSH_REGISTER") | .id' 2>/dev/null | head -1)
  if [ -n "$REG_ID" ]; then
    echo "[$(date)] [poll] Found HARMRAID_PUSH_REGISTER id=$REG_ID" >> "$LOG"
    DESC=$(echo "$RESULT" | jq -r ".data.notifications.list[] | select(.id == \"$REG_ID\") | .description" 2>/dev/null)
    echo "[$(date)] [poll] description: $(echo "$DESC" | head -c 200)" >> "$LOG"
    TOKEN=$(echo "$DESC" | jq -r '.token // empty' 2>/dev/null)
    DEVICE=$(echo "$DESC" | jq -r '.device_name // empty' 2>/dev/null)
    echo "[$(date)] [poll] token=${TOKEN:0:16}... device=$DEVICE" >> "$LOG"
    [ -z "$TOKEN" ] && echo "[$(date)] [poll] token empty, skip" >> "$LOG" && continue
    mkdir -p /boot/config/plugins/harmraid-push
    echo "$TOKEN" >> /boot/config/plugins/harmraid-push/push_token.txt
    echo "[$(date)] [poll] token appended to push_token.txt" >> "$LOG"
    DEVICES=$(cat /boot/config/plugins/harmraid-push/devices.json 2>/dev/null || echo "[]")
    echo "$DEVICES" | jq --arg t "$TOKEN" --arg n "${DEVICE:-未知设备}" '. + [{"token": $t, "device_name": $n}]' > /boot/config/plugins/harmraid-push/devices.json 2>/dev/null
    echo "[$(date)] [poll] devices.json updated" >> "$LOG"
    ARCHIVE=$(curl -s http://localhost/graphql -H "Content-Type: application/json" \
      -d '{"query":"mutation { archiveNotification(id: \"'$REG_ID'\") { id } }"}')
    echo "[$(date)] [poll] archive result: $(echo "$ARCHIVE" | head -c 100)" >> "$LOG"
    /usr/local/emhttp/plugins/harmraid-push/send-push.sh "推送注册成功" "设备已注册" "info" >/dev/null 2>&1
    echo "[$(date)] [poll] test push done" >> "$LOG"
    logger -t harmraid-push "Device registered successfully"
    echo "[$(date)] [poll] Done" >> "$LOG"
    break
  fi
done
echo "[$(date)] [poll] Background poll finished" >> "$LOG"
