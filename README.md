# Harmraid Push

Unraid push notification plugin for [Harmraid](https://github.com/shanyan-wcx/Harmraid) app.

Forwards Unraid notifications to your HarmonyOS device via **HMS Push Kit**.

## Features

- Real-time push notifications from Unraid to your phone
- Configurable notification types (alert, warning, error, info)
- Toggle push on/off from Unraid WebGUI
- Secure HMS credentials stored on USB flash drive
- Works even when Harmraid app is killed (system-level push)

## Requirements

- Unraid 6.12+
- Harmraid app installed on a HarmonyOS device (API 24+)
- HMS Push Kit credentials from [AppGallery Connect](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html)

## Installation

### Via Unraid Community Apps (recommended)

1. Open Unraid WebGUI
2. Go to **Apps** tab
3. Search for **Harmraid Push**
4. Click **Install**

### Manual Installation

```bash
# SSH into your Unraid server
cd /tmp
wget https://raw.githubusercontent.com/shanyan-wcx/Harmraid-Push/main/harmraid-push.plg
installplg harmraid-push.plg
```

Or via Unraid WebGUI:
1. Go to **Plugins** tab
2. Paste `https://raw.githubusercontent.com/shanyan-wcx/Harmraid-Push/main/harmraid-push.plg`
3. Click **Install**

## Configuration

1. Go to **Settings > Notification Settings** in Unraid WebGUI
2. Enable push notifications
3. Select notification types to forward
4. Enter your HMS App ID and App Secret
5. Open Harmraid app and register your device

## HMS Setup

1. Go to [AppGallery Connect](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html)
2. Create a project and add a HarmonyOS app
3. Enable **Push Kit**
4. Note your **App ID** and **App Secret**
5. Enter these in the plugin settings page

## How It Works

```
Unraid Notification → event/notify hook → send-push.sh
                                            ↓
                                   HMS Push API
                                            ↓
                          HarmonyOS Device ← Push Kit
```

The plugin hooks into Unraid's notification system. When a notification matching the configured types is created, the plugin:
1. Receives the notification via the `event/notify` hook
2. Gets an HMS OAuth token using your credentials
3. Sends the push message to all registered devices via HMS Push API

## Files

| Path | Purpose |
|------|---------|
| `/usr/local/emhttp/plugins/harmraid-push/harmraid-push.page` | WebGUI settings page |
| `/usr/local/emhttp/plugins/harmraid-push/send-push.sh` | Push sending script |
| `/usr/local/emhttp/plugins/harmraid-push/event/notify` | Notification hook |
| `/usr/local/emhttp/plugins/harmraid-push/scripts/configure-push` | Config helper |
| `/boot/config/plugins/harmraid-push/push_enabled.txt` | Push toggle |
| `/boot/config/plugins/harmraid-push/types.txt` | Notification types |
| `/boot/config/plugins/harmraid-push/app_id.txt` | HMS App ID |
| `/boot/config/plugins/harmraid-push/app_secret.txt` | HMS App Secret |
| `/boot/config/plugins/harmraid-push/push_token.txt` | Device push token |

## License

MIT
