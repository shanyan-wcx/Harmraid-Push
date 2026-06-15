# Harmraid Push

[Harmraid](https://github.com/shanyan-wcx/Harmraid) 应用的 Unraid 推送通知插件。

将 Unraid 的通知通过 **HMS Push Kit** 推送到您的 HarmonyOS 设备。

## 功能

- 实时推送 Unraid 通知到手机
- 可配置通知类型（告警、警告、错误、普通通知）
- 在 Unraid WebGUI 中启停推送
- 无需应用常驻后台（系统级推送）

## 要求

- Unraid 6.12+
- 已安装 [Harmraid](https://github.com/shanyan-wcx/Harmraid) 应用的 HarmonyOS 设备（API 24+）

## 安装

### 通过 Community Apps（推荐）

1. 打开 Unraid WebGUI
2. 进入 **Apps** 页面
3. 搜索 **Harmraid Push**
4. 点击 **Install**

### 手动安装

```bash
# 通过 SSH 连接到 Unraid 服务器
cd /tmp
wget https://raw.githubusercontent.com/shanyan-wcx/Harmraid-Push/main/harmraid-push.plg
installplg harmraid-push.plg
```

或通过 Unraid WebGUI：
1. 进入 **Plugins** 页面
2. 粘贴 `https://raw.githubusercontent.com/shanyan-wcx/Harmraid-Push/main/harmraid-push.plg`
3. 点击 **Install**

## 配置

1. 打开 Unraid WebGUI，进入 **Settings > Notification Settings**
2. 启用推送开关
3. 选择要推送的通知类型
4. 打开 Harmraid App，在 **设置 > 通知推送** 中注册设备

## 推送机制

```
Unraid 通知 → event/notify 钩子 → send-push.sh
                                         ↓
                                HMS Push API
                                         ↓
                          HarmonyOS 设备 ← Push Kit
```

插件拦截 Unraid 的通知事件，将符合条件的通知转发到 HMS Push API，最终送达您的 HarmonyOS 设备。

## 文件说明

| 路径 | 用途 |
|------|------|
| `/usr/local/emhttp/plugins/harmraid-push/harmraid-push.page` | WebGUI 设置页面 |
| `/usr/local/emhttp/plugins/harmraid-push/send-push.sh` | 推送发送脚本 |
| `/usr/local/emhttp/plugins/harmraid-push/event/notify` | 通知事件钩子 |
| `/usr/local/emhttp/plugins/harmraid-push/scripts/configure-push` | 配置脚本 |
| `/boot/config/plugins/harmraid-push/push_enabled.txt` | 推送开关 |
| `/boot/config/plugins/harmraid-push/types.txt` | 通知类型配置 |
| `/boot/config/plugins/harmraid-push/push_token.txt` | 设备推送令牌 |
| `/boot/config/plugins/harmraid-push/app_id.txt` | HMS App ID |
| `/boot/config/plugins/harmraid-push/app_secret.txt` | HMS App Secret |

## 许可证

MIT
